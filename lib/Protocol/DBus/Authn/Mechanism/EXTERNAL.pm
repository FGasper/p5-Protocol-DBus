package Protocol::DBus::Authn::Mechanism::EXTERNAL;

use strict;
use warnings;

use parent 'Protocol::DBus::Authn::Mechanism';

use Protocol::DBus::Socket ();

# The methods of user credential retrieval that the reference D-Bus
# server relies on prefer “out-of-band” methods like SO_PEERCRED
# on Linux rather than SCM_CREDS. (See See dbus/dbus-sysdeps-unix.c.)
# So for some OSes it’s just not necessary to do anything special to
# send credentials.
#
# On other OSes it’s just not possible to send credentials via a
# UNIX socket in the first place.
#
our @OS_NO_MSGHDR_LIST = (

    # Reference server doesn’t need our help:
    'linux',
    'netbsd',

    # 'openbsd', ??? Still trying to test.

    # No way to pass credentials via UNIX socket anyway:
    'cygwin',
    'darwin',
);

sub INITIAL_RESPONSE { unpack 'H*', $> }

# The reference server implementation does a number of things to try to
# fetch the peer credentials. .
sub must_send_initial {
    my ($self) = @_;

    if (!defined $self->{'_must_send_initial'}) {

        my $can_skip_msghdr = grep { $_ eq $^O } @OS_NO_MSGHDR_LIST;

        $can_skip_msghdr ||= eval { my $v = Socket::SO_PEERCRED(); 1 };
        $can_skip_msghdr ||= eval { my $v = Socket::LOCAL_PEEREID(); 1 };

        $self->{'_must_send_initial'} = !$can_skip_msghdr;
    }

    return $self->{'_must_send_initial'};
}

sub send_initial {
    my ($self, $s) = @_;

    eval { require Socket::MsgHdr; 1 } or do {
        die "Socket::MsgHdr appears to be needed for EXTERNAL authn (OS=$^O) but failed to load: $@";
    };

    my $msg = Socket::MsgHdr->new( buf => "\0" );

    # The kernel should fill in the payload.
    $msg->cmsghdr( Socket::SOL_SOCKET(), Socket::SCM_CREDS(), "\0" x 64 );

    local $!;
    my $ok = Protocol::DBus::Socket::sendmsg_nosignal($s, $msg, 0);

    if (!$ok && !$!{'EAGAIN'}) {
        die "sendmsg($s): $!";
    }

    return $ok;
}

1;
