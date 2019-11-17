package Protocol::DBus::Client::IOAsync;

use strict;
use warnings;

# XXX TODO: Needs a listener for signals. (And unbidden errors?)

=encoding utf-8

=head1 NAME

Protocol::DBus::Client::AnyEvent - D-Bus with L<AnyEvent>

=head1 SYNOPSIS

The following creates a D-Bus connection, sends two messages,
waits for their responses, then ends:

    use experimental 'signatures';

    my $dbus = Protocol::DBus::Client::AnyEvent::system()

    my $cv = AnyEvent->condvar();

    $dbus->initialize()->then(
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

use parent qw( Protocol::DBus::Client::Async );

use Scalar::Util ();

use IO::Async::Handle ();

use Promise::ES6 ();

use Protocol::DBus::Client ();
use Protocol::DBus::Client::AsyncMessenger ();

#----------------------------------------------------------------------

=head1 STATIC FUNCTIONS


This module offers C<system()> and C<login_session()> functions that
offer similar functionality to their analogues in
L<Protocol::DBus::Client>, but they return instances of this class.

Additionally, you B<must> pass an L<IO::Async::Loop> instance to either
function.

=cut

sub system {
    return __PACKAGE__->_create(Protocol::DBus::Client::system(), $_[0] );
}

sub login_session {
    return __PACKAGE__->_create(Protocol::DBus::Client::login_session(), $_[0] );
}

sub _create {
    my ($class, $dbus, $loop) = @_;

    die 'need loop!' if !$loop;

    open my $s, '+>&=' . $dbus->fileno() or die "failed to dupe filehandle: $!";

    return $class->SUPER::_create($dbus, loop => $loop, socket => $s);
}

#----------------------------------------------------------------------

=head1 INSTANCE METHODS

=head2 $promise = I<OBJ>->initialize()

Returns a promise (L<Promise::ES6> instance) that resolves to a
L<Protocol::DBus::Client::AsyncMessenger> instance. That object is
what you’ll use to send and receive messages.

=cut

sub _initialize {
    my ($self, $y, $n) = @_;

    my $dbus = $self->{'db'};
    my $loop = $self->{'loop'};
    my $s = $self->{'socket'};

    my $weak_watch;

    my $each_time = sub {
        $weak_watch->want_writeready(0);

        $n->($@) if !eval {
            if ( $dbus->initialize() ) {
                $loop->remove($weak_watch);
                $y->();
            }
            else {
                $weak_watch->want_writeready( $dbus->init_pending_send() );
            }

            1;
        };
    };

    my $watch = IO::Async::Handle->new(
        handle => $s,

        on_read_ready => $each_time,
        on_write_ready => $each_time,
    );

    # weaken() is needed to prevent a memory leak:
    Scalar::Util::weaken($weak_watch = $watch);

    $loop->add($watch);

    $each_time->();
}

#----------------------------------------------------------------------

sub _set_watches_and_create_messenger {
    my ($self) = @_;

    my $dbus = $self->{'db'};
    my $socket = $self->{'socket'};

    my $weak_watch;

    my $watch = IO::Async::Handle->new(
        handle => $socket,

        on_read_ready => $self->_create_get_message_callback(),

        on_write_ready => sub {
            $weak_watch->want_writeready(0) if $dbus->flush_write_queue();
        },
    );
    $self->{'loop'}->add($watch);

    $self->{'watch'} = $watch;

    # weaken() is needed to prevent a memory leak:
    Scalar::Util::weaken($weak_watch = $self->{'watch'});

    return $self->{'_messenger'} = Protocol::DBus::Client::AsyncMessenger->new(
        $dbus,
        sub {
            $watch->want_writeready( $dbus->pending_send() );
        },
    );
}

our @ISA;

sub DESTROY {
    if (my $watch = delete $_[0]{'watch'}) {
        $_[0]{'loop'}->remove($watch);
    }

    $_[0]->SUPER::DESTROY() if $ISA[0]->can('DESTROY');

    return;
}

1;
