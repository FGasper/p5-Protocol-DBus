package Protocol::DBus::Client::AnyEvent;

use strict;
use warnings;

use constant _has_current_sub => $^V ge v5.16.0;

use if _has_current_sub(), feature => 'current_sub';

# XXX TODO: Needs a listener for unbidden errors.

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

use AnyEvent ();

use Promise::ES6 ();

use Protocol::DBus::Client ();
use Protocol::DBus::Client::AsyncMessenger ();

#----------------------------------------------------------------------

=head1 STATIC FUNCTIONS

This module offers C<system()> and C<login_session()> functions that
offer similar functionality to their analogues in
L<Protocol::DBus::Client>, but they return instances of this class.

=cut

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

    my $fileno = $dbus->fileno();

    my $read_watch_r = \do { $self->{'_read_watch'} = undef };
    my $write_watch_r = \do { $self->{'_write_watch'} = undef };

    my $cb;
    $cb = sub {
        if ( $dbus->initialize() ) {
            undef $$read_watch_r;
            undef $$write_watch_r;
            $y->();
        }

        # It seems unlikely that we’d need a write watch here.
        # But just in case …
        elsif ($dbus->init_pending_send()) {
            $$write_watch_r ||= do {

                # Accommodate Perl versions whose $@ handling is buggy
                # by forgoing local():
                my $old_err = $@;

                my $current_sub = do {
                    no strict 'subs';

                    # We can’t refer to $cb in the code or else
                    # this will leak.
                    _has_current_sub() ? __SUB__ : eval '$cb';
                };

                $@ = $old_err;

                AnyEvent->io(
                    fh => $fileno,
                    poll => 'w',
                    cb => $current_sub,
                );
            };
        }
        else {
            undef $$write_watch_r;
        }
    };

    $$read_watch_r = AnyEvent->io(
        fh => $fileno,
        poll => 'r',
        cb => $cb,
    );

    $cb->();
}

#----------------------------------------------------------------------

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

sub _wrap_send {
    my ($self) = @_;

    my $fn = (caller 1)[3];
    substr( $fn, 0, 1 + rindex($fn, ':') ) = q<>;

    my $dbus = $self->{'db'};

    my $ret = $dbus->$fn( @_[1 .. $#_] );

    _flush_send_queue( $dbus, $dbus->fileno(), $self->{'_send_watch_ref'} );

    return $ret;
}

sub _set_watches_and_create_messenger {
    my ($self) = @_;

    my $dbus = $self->{'db'};

    my $fileno = $dbus->fileno();

    if (!$self->{'_read_watch'}) {

        my $watch = undef;
        _flush_send_queue( $dbus, $fileno, \$watch );

        $self->{'_send_watch_ref'} = \$watch;

        $self->{'_read_watch'} = AnyEvent->io(
            fh => $fileno,
            poll => 'r',
            cb => $self->_create_get_message_callback($dbus, $self->{'_on_signal'}),
        );
    }

    my $watch_sr = $self->{'_send_watch_ref'};

    return $self->{'_messenger'} = Protocol::DBus::Client::AsyncMessenger->new(
        $dbus,
        sub { _flush_send_queue( $dbus, $fileno, $watch_sr ) },
    );
}

1;
