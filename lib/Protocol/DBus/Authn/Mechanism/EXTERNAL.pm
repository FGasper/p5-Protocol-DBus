package Protocol::DBus::Authn::Mechanism::EXTERNAL;

use strict;
use warnings;

use parent 'Protocol::DBus::Authn::Mechanism';

sub INITIAL_RESPONSE { unpack 'H*', $> }

sub must_send_initial {
    my ($self) = @_;

    if (!defined $self->{'_must_send_initial'}) {

        # On Linux and BSD OSes this module doesn’t need to make any special
        # effort to send credentials because the server will request them on
        # its own. (Although Linux only sends the real credentials, we’ll
        # send the EUID in the EXTERNAL handshake.)
        #
        my $can_skip_msghdr = Socket->can('SCM_CREDENTIALS');

        # MacOS doesn’t appear to have an equivalent to SO_PASSCRED
        # but does have SCM_CREDS, so we have to blacklist it specifically.
        $can_skip_msghdr ||= Socket->can('SCM_CREDS') && !grep { $^O eq $_ } qw( darwin cygwin );

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
