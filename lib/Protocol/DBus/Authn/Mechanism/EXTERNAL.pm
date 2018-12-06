package Protocol::DBus::Authn::Mechanism::EXTERNAL;

use strict;
use warnings;

use parent 'Protocol::DBus::Authn::Mechanism';

sub INITIAL_RESPONSE { unpack 'H*', $> }

# The reference server implementation does a number of things to try to
# fetch the peer credentials. See dbus/dbus-sysdeps-unix.c.
sub must_send_initial {
    my ($self) = @_;

    if (!defined $self->{'_must_send_initial'}) {

        # On Linux and BSD OSes this module doesn’t need to make any special
        # effort to send credentials because the server will request them on
        # its own. (Although Linux only sends the real credentials, we’ll
        # send the EUID in the EXTERNAL handshake.)
        #
        my $can_skip_msghdr = Socket->can('SO_PEERCRED');
        $can_skip_msghdr ||= Socket->can('LOCAL_PEEREID');
        $can_skip_msghdr ||= Socket->can('LOCAL_PEERCRED');

        $self->{'_must_send_initial'} = !$can_skip_msghdr;
    }

    return $self->{'_must_send_initial'};
}

sub send_initial {
    my ($self) = @_;

    # There are no known platforms where sendmsg will achieve anything
    # that plain write() doesn’t already get us.
    die "Unsupported OS: $^O";
}

1;
