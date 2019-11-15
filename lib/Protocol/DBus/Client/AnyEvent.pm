package Protocol::DBus::Client::AnyEvent;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Protocol::DBus::Client::AnyEvent - D-Bus with L<AnyEvent>

=head1 SYNOPSIS

The following creates a D-Bus connection, sends two messages,
waits for their responses, then ends:

    use experimental 'signatures';

    my $cv = AnyEvent->condvar();

    Protocol::DBus::Client::AnyEvent::system()->then(
        sub ($dbus) {
            my $a = $dbus->send_call( .. )->then( sub ($resp) {
                # ..
            } );

            my $b = $dbus->send_call( .. )->then( sub ($resp) {
                # ..
            } );

            return Promise::ES6->all( [$a, $b] );
        },
    )->finally($cv);

    $cv->recv();

=head1 DESCRIPTION

This module provides an L<AnyEvent> interface on top of
L<Protocol::DBus::Client>.

=cut

use AnyEvent ();

use Promise::ES6::AnyEvent ();

use Protocol::DBus::Client ();

sub system {
    return _initialize(Protocol::DBus::Client::system());
}

sub login_session {
    return _initialize(Protocol::DBus::Client::login_session());
}

sub _initialize {
    my ($dbus) = @_;

    $dbus->blocking(0);

    return Promise::ES6::AnyEvent->new( sub {
        my ($y, $n) = @_;

        my $fileno = $dbus->fileno();

        my $watch;

        my $each_time;
        $each_time = sub {
            $watch = undef;

            $n->($@) if !eval {
                if ( $dbus->initialize() ) {
                    $y->( __PACKAGE__->_new($dbus)->_set_watches() );
                }
                else {
                    $watch = AnyEvent->io(
                        fh => $fileno,
                        poll => $dbus->init_pending_send() ? 'w' : 'r',
                        cb => $each_time,
                    );
                }

                1;
            };
        };

        $each_time->();
    } );
}

sub _new {
    my ($class, $dbus) = @_;

    return bless( { db => $dbus }, $class );
}

sub _flush_send_queue {
    my ($dbus, $fileno, $watch_sr) = @_;

    if ($dbus->pending_send()) {
        $$watch_sr = AnyEvent->io(
            fh => $fileno,
            poll => 'w',
            cb => sub { $$watch_sr = undef if $dbus->flush_write_queue() },
        );
    }

    return;
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

    _flush_send_queue( $dbus, $dbus->fileno(), $self->{'_send_watch_ref'} );

    return $ret;
}

sub _set_watches {
    my ($self) = @_;

    my $dbus = $self->{'db'};

    my $fileno = $dbus->fileno();

    my $watch = undef;
    _flush_send_queue( $dbus, $fileno, \$watch );

    $self->{'_send_watch_ref'} = \$watch;

    $self->{'_read_watch'} = AnyEvent->io(
        fh => $fileno,
        poll => 'r',
        cb => sub {
            1 while $dbus->get_message();
        },
    );

    return $self;
}

1;
