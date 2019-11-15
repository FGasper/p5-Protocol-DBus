package Protocol::DBus::Client::IOAsync;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Protocol::DBus::Client::IOAsync

=cut

#----------------------------------------------------------------------

use IO::Async::Handle ();

use Promise::ES6 ();

use Protocol::DBus::Client ();

sub system {
    return _initialize(Protocol::DBus::Client::system(), $_[0]);
}

sub login_session {
    return _initialize(Protocol::DBus::Client::login_session(), $_[0]);
}

sub _initialize {
    my ($dbus, $loop) = @_;

    $dbus->blocking(0);

    open my $s, '+>&=' . $dbus->fileno() or die "failed to dupe filehandle: $!";

    return Promise::ES6->new( sub {
        my ($y, $n) = @_;

        my $watch;

        my $each_time = sub {
            $watch->want_writeready(0);

            $n->($@) if !eval {
                if ( $dbus->initialize() ) {
                    $loop->remove($watch);
                    $y->( __PACKAGE__->_new($dbus, $s, $loop) );
                }
                else {
                    $watch->want_writeready( $dbus->init_pending_send() );
                }

                1;
            };
        };

        $watch = IO::Async::Handle->new(
            handle => $s,

            on_read_ready => $each_time,
            on_write_ready => $each_time,
        );

        $loop->add($watch);

        $each_time->();
    } );
}

sub send_call {
    return _wrap_send( @_ );
}

sub send_return {
    return _wrap_send( @_ );
}

sub send_error {
    return _wrap_send( @_ );
}

sub send_signal {
    return _wrap_send( @_ );
}

sub _wrap_send {
    my ($self) = @_;

    my $fn = (caller 1)[3];
    substr( $fn, 0, 1 + rindex($fn, ':') ) = q<>;

    my $dbus = $self->{'db'};

    my $ret = $dbus->$fn( @_[1 .. $#_] );

    $self->{'watch'}->want_writeready( $dbus->pending_send() );

    return $ret;
}

sub _new {
    my ($class, $dbus, $socket, $loop) = @_;

    my $watch;
    $watch = IO::Async::Handle->new(
        handle => $socket,

        on_read_ready => sub {
            1 while $dbus->get_message();
        },

        on_write_ready => sub {
            $watch->want_writeready(0) if $dbus->flush_write_queue();
        },
    );

    $watch->want_writeready( $dbus->pending_send() );

    $loop->add($watch);

    return bless { db => $dbus, watch => $watch }, $class;
}

sub DESTROY {
    print "I DIE HORATIO\n";
}

1;
