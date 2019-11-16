package Protocol::DBus::Client::Async;

use strict;
use warnings;

sub system {
    return $_[0]->_create(Protocol::DBus::Client::system(), @_[ 1 .. $#_ ]);
}

sub login_session {
    return $_[0]->_create(Protocol::DBus::Client::login_session(), @_[ 1 .. $#_ ]);
}

sub initialize {
    my ($self) = @_;

    return $self->{'_initialize_promise'} ||= Promise::ES6->new( sub {
        $self->_initialize(@_);
    } )->then( sub { $self->_set_watches_and_create_messenger() } );
}

sub on_signal {
    my ($self, $cb) = @_;

    $self->{'_on_signal'} = $cb;

    return $self;
}

sub _create {
    my ($class, $dbus, %opts) = @_;

    $opts{'db'} = $dbus;

    $dbus->blocking(0);

    return bless \%opts, $class;
}

sub _create_get_message_callback {
    my ($self, $dbus, $on_signal_cr) = @_;

    return sub {
        while (my $msg = $dbus->get_message()) {
            if ($on_signal_cr && $msg->type_is('SIGNAL')) {
                $on_signal_cr->($msg);
            }
        }
    };
}

1;
