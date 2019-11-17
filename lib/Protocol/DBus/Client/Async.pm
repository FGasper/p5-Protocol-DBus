package Protocol::DBus::Client::Async;

use strict;
use warnings;

=head1 INSTANCE METHODS

=head2 $promise = I<OBJ>->initialize()

Returns a promise (L<Promise::ES6> instance) that resolves to a
L<Protocol::DBus::Client::AsyncMessenger> instance. That object is
what you’ll use to send and receive messages.

=cut

sub initialize {
    my ($self) = @_;

    return $self->{'_initialize_promise'} ||= Promise::ES6->new( sub {
        $self->_initialize(@_);
    } )->then( sub { $self->_set_watches_and_create_messenger() } );
}

=head2 $obj = I<OBJ>->on_signal( $HANDLER_CR )

Installs a handler for D-Bus signals. Whenever I<OBJ> receives such a
message, an instance of L<Protocol::DBus::Message> that represents the
message will be passed to $HANDLER_CR.

Pass undef to disable a previously-set handler.

Returns I<OBJ>.

=cut

sub on_signal {
    my ($self, $cb) = @_;

    $self->{'_on_signal_r'} = \$cb;

    return $self;
}

=head2 $obj = I<OBJ>->on_message( $HANDLER_CR )

Like C<on_signal()> but for all received D-Bus messages, not just signals.
This is useful for monitoring.

=cut

sub on_message {
    my ($self, $cb) = @_;

    $self->{'_on_message_r'} = \$cb;

    return $self;
}

#----------------------------------------------------------------------

sub _create {
    my ($class, $dbus, %opts) = @_;

    $opts{'db'} = $dbus;

    $dbus->blocking(0);

    return bless \%opts, $class;
}

sub _create_get_message_callback {
    my ($self) = @_;

    my $dbus = $self->{'db'};

    my $on_message_cr_r = $self->{'_on_message_r'} ||= \do { my $v = undef };
    my $on_signal_cr_r = $self->{'_on_signal_r'} ||= \do { my $v = undef };

    return sub {
        while (my $msg = $dbus->get_message()) {
            if ($$on_message_cr_r) {
                $$on_message_cr_r->($msg);
            }

            if ($$on_signal_cr_r && $msg->type_is('SIGNAL')) {
                $$on_signal_cr_r->($msg);
            }
        }
    };
}

1;
