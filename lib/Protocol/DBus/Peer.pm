package Protocol::DBus::Peer;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Protocol::DBus::Peer - base class for a D-Bus peer

=head1 SYNOPSIS

    $dbus->send_call(
        interface => 'org.freedesktop.DBus.Properties',
        member => 'GetAll',
        signature => 's',
        path => '/org/freedesktop/DBus',
        destination => 'org.freedesktop.DBus',
        body => [ 'org.freedesktop.DBus' ],
    )->then( sub { .. } );

    my $msg = $dbus->get_message();

    # Same pattern as the IO::Handle method.
    $dbus->blocking(0);

    my $fileno = $dbus->fileno();

    $dbus->flush_write_queue() if $dbus->pending_send();

    # I’m not sure why you’d want to do this, but …
    $dbus->big_endian();

=head1 DESCRIPTION

This class contains D-Bus logic that is useful in both client and
server contexts. (Currently this distribution does not include a server
implementation.)

=cut

use Call::Context;

use Protocol::DBus::Message;
use Protocol::DBus::Parser;
use Protocol::DBus::WriteMsg;

use constant _PROMISE_CLASS => 'Promise::ES6';

#----------------------------------------------------------------------

=head1 METHODS

=head2 $msg = I<OBJ>->get_message()

This returns a single instace of L<Protocol::DBus::Message>, or undef if
no message is available. It will also fire the appropriate “on_return”
method on METHOD_RETURN or ERROR messages.

The backend I/O logic reads data in chunks; thus, if there is a message
already available in the read buffer, no I/O is done. If you’re doing
non-blocking I/O then it is thus B<vital> that, every time the DBus socket
is readable, you call this function until undef is returned.

=cut

sub get_message {
    my $msg = $_[0]->{'_parser'}->get_message();

    if ($msg) {
        if (my $serial = $msg->get_header('REPLY_SERIAL')) {
            delete $_[0]->{'_on_armageddon'}{$serial};

            if (my $cb = delete $_[0]->{'_on_return'}{$serial}) {
                $cb->($msg);
            }
        }
    }

    return $msg;
}

#----------------------------------------------------------------------

=head2 I<OBJ>->flush_write_queue()

Same as L<IO::Framed::Write>’s method of the same name.

=cut

sub flush_write_queue {
    if ($_[0]->{'_io'}->get_write_queue_count()) {
        return $_[0]->{'_io'}->flush_write_queue();
    }

    return 1;
}

#----------------------------------------------------------------------

=head2 $promise = I<OBJ>->send_call( %OPTS )

Send a METHOD_CALL message.

%OPTS are C<path>, C<interface>, C<member>, C<destination>, C<signature>,
and C<body>. These do as you’d expect, but note that C<body>, if given,
must be an array reference.

C<flags> may be given as an array reference of strings, e.g.,
C<NO_REPLY_EXPECTED>. See the D-Bus Specification for all possible values.

The return value is an instance of L<Promise::ES6>. Normally this promise
resolves when a METHOD_RETURN arrives in response. The resolution value is a
a L<Protocol::DBus::Message> instance that represents the response. If,
however, C<flags> is given and contains C<NO_REPLY_EXPECTED>, the promise
resolves as soon as the message is sent.

If an ERROR arrives in response instead, the promise will instead reject
with a L<Protocol::DBus::Message> instance that represents that ERROR.
The promise will also reject if some other error happens (e.g., an I/O
error while sending the initial METHOD_CALL).

=cut

use constant _METHOD_RETURN_NUM => Protocol::DBus::Message::Header::MESSAGE_TYPE()->{'METHOD_RETURN'};

sub _get_promise_class {
    my ($self) = @_;

    $self->{'_loaded_promise'} ||= do {
        local ($!, $@);
        my $path = $self->_PROMISE_CLASS() . '.pm';
        $path =~ s[::][/]g;

        require $path;
    };

    return $self->_PROMISE_CLASS();
}

sub send_call {
    my ($self, %opts) = @_;

    my ($res, $rej, $response_expected);

    my $ok;

    my $promise_class = $self->_get_promise_class();

    my $serial;

    my $on_armageddon_hr = $self->{'_on_armageddon'} ||= {};

    my $promise = $promise_class->new( sub {
        ($res, $rej) = @_;

        if ($opts{'flags'} && grep { $_ eq 'NO_REPLY_EXPECTED' } @{ $opts{'flags'} }) {
            $response_expected = 0;
        }
        else {
            $response_expected = 1;
        }

        $self->_send_msg(
            $res,
            %opts,
            type => 'METHOD_CALL',
        );

        $serial = $self->{'_last_sent_serial'};

        $on_armageddon_hr->{$serial} = $rej;

        $ok = 1;
    } )->finally( sub {
        delete $on_armageddon_hr->{$serial} if $serial;
    } );

    if ($ok && $response_expected) {
        # Keep references to $self out of the callback
        # in order to avoid memory leaks.
        my $on_return_hr = $self->{'_on_return'} ||= {};

        my $orig_promise = $promise;

        $promise = $promise->then( sub {

            return $promise_class->new( sub {
                my ($res, $rej) = @_;

                $on_armageddon_hr->{$serial} = $rej;

                $on_return_hr->{$serial} = sub {
                    if ($_[0]->get_type() == _METHOD_RETURN_NUM()) {
                        $res->($_[0]);
                    }
                    else {
                        $rej->($_[0]);
                    }
                };
            } );
        } );
    }

    return $promise;
}

=head2 $promise = I<OBJ>->send_return( $ORIG_MSG, %OPTS )

Send a METHOD_RETURN message.

The return is a promise that resolves when the message is sent.

Arguments are similar to C<send_call()> except for the header differences
that the D-Bus specification describes. Also, C<destination> is not given
directly but is instead inferred from the $ORIG_MSG. (Behavior is
undefined if this parameter is given directly.)

=cut

sub send_return {
    my ($self, $orig_msg, @opts_kv) = @_;

    return $self->_get_promise_class()->new( sub {
        my ($res) = @_;

        $self->_send_msg(
            $res,
            _response_fields_from_orig_msg($orig_msg, \@opts_kv),
            type => 'METHOD_RETURN',
        );
    } );
}

=head2 $promise = I<OBJ>->send_error( $ORIG_MSG, %OPTS )

Like C<send_return()>, but sends an error instead. The
C<error_name> parameter is required.

=cut

sub send_error {
    my ($self, $orig_msg, @opts_kv) = @_;

    return $self->_get_promise_class()->new( sub {
        my ($res) = @_;

        $self->_send_msg(
            $res,
            _response_fields_from_orig_msg($orig_msg, \@opts_kv),
            type => 'ERROR',
        );
    } );
}

sub _response_fields_from_orig_msg {

    return (

        # This has to honor a passed “destination”
        # so that we can implement a D-Bus server in tests.
        destination => $_[0]->get_header('SENDER'),

        @{ $_[1] },

        # Reject callers’ attempts to set this one.
        reply_serial => $_[0]->get_serial(),
    );
}

=head2 $promise = I<OBJ>->send_signal( %OPTS )

Like C<send_call()> but sends a signal rather than a method call.

=cut

sub send_signal {
    my ($self, @opts_kv) = @_;

    return $self->_get_promise_class()->new( sub {
        my ($res) = @_;

        $self->_send_msg(
            $res,
            @opts_kv,
            type => 'SIGNAL',
        );
    } );
}

#----------------------------------------------------------------------

=head2 I<OBJ>->big_endian()

Same interface as C<blocking()>, but this sets/gets/toggles whether to send
big-endian messages instead of little-endian.

By default this library uses the system’s native byte order, so you probably
have little need for this function.

=cut

sub big_endian {
    my ($self) = @_;

    if (@_ > 1) {
        my $old = $self->{'_big_endian'};
        $self->{'_big_endian'} = !!$_[1];

        $self->{'_to_str_fn'} = 'to_string_' . ($_[1] ? 'be' : 'le');

        return $self->{'_big_endian'};
    }

    return !!$self->{'_big_endian'};
}

#----------------------------------------------------------------------

=head2 I<OBJ>->preserve_variant_signatures()

Same interface as C<blocking()>, but when this is enabled
variants are given as two-member array references ([ signature => value ]),
blessed as C<Protocol::DBus::Type::Variant> instances.

For most Perl applications this is probably counterproductive.

=cut

sub preserve_variant_signatures {
    my $self = shift;

    return $self->{'_parser'}->preserve_variant_signatures(@_);
}

#----------------------------------------------------------------------

=head2 I<OBJ>->blocking()

Same interface as L<IO::Handle>’s method of the same name.

=cut

sub blocking {
    my $self = shift;

    # require() is needed on pre-5.14 perls:
    if ($^V lt v5.14) {
        local ($@, $!);
        require IO::File;
    }

    return $self->{'_socket'}->blocking(@_);
}

#----------------------------------------------------------------------

=head2 I<OBJ>->fileno()

Returns the connection socket’s file descriptor.

=cut

sub fileno {
    return fileno $_[0]->{'_socket'};
}

#----------------------------------------------------------------------

=head2 I<OBJ>->pending_send()

Returns a boolean that indicates whether there is data queued up to send
to the server.

=cut

sub pending_send {
    return !!$_[0]->{'_io'}->get_write_queue_count();
}

#----------------------------------------------------------------------

# undocumented
sub new {
    my ($class, $socket) = @_;

    my $self = bless { _socket => $socket }, $class;

    $self->_set_up_peer_io( $socket );

    return $self;
}

sub do_armageddon {
    my ($self, $why) = @_;

    %{ $self->{'_on_return'} } = ();

    my $on_armageddon_hr = $self->{'_on_armageddon'};

    my @cbs = delete @{$on_armageddon_hr}{ keys %$on_armageddon_hr };

    $_->($why) for @cbs;

    return;
}

#----------------------------------------------------------------------

sub _set_up_peer_io {
    my ($self, $socket) = @_;

    $self->{'_io'} = Protocol::DBus::WriteMsg->new( $socket )->enable_write_queue();
    $self->{'_parser'} = Protocol::DBus::Parser->new( $socket );

    return;
}

sub _send_msg {
    my ($self, $on_send, %opts) = @_;

    my ($type, $body_ar, $flags) = delete @opts{'type', 'body', 'flags'};

    my @hargs = map {
        my $k = $_;
        $k =~ tr<a-z><A-Z>;
        ( $k => $opts{$_} );
    } keys %opts;

    my $serial = ++$self->{'_last_sent_serial'};

    my $msg = Protocol::DBus::Message->new(
        type => $type,
        hfields => \@hargs,
        flags => $flags,
        body => $body_ar,
        serial => $serial,
    );

    # Use native byte order by default.
    $self->{'_endian'} ||= (pack 'n', 1) eq (pack 'l', 1) ? 'be' : 'le';

    $self->{'_to_str_fn'} ||= "to_string_$self->{'_endian'}";

    my ($buf_sr, $fds_ar) = $msg->can($self->{'_to_str_fn'})->($msg);

    if ($fds_ar && @$fds_ar && !$self->supports_unix_fd()) {
        die "Cannot send file descriptors without UNIX FD support!";
    }

    $self->{'_io'}->enqueue_message( $buf_sr, $fds_ar, $on_send );

    return $self->{'_io'}->flush_write_queue();
}

1;
