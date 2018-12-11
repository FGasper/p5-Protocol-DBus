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
# On other OSes it doesn’t seem possible to send credentials via a
# UNIX socket in the first place. But let’s still try.
#
our @OS_NO_MSGHDR_LIST = (

    # Reference server doesn’t need our help:
    'linux',
    'netbsd',   # via LOCAL_PEEREID, which dbus calls

    # LOCAL_PEERCRED exists and works, but the reference server
    # doesn’t appear to use it. Nonetheless, EXTERNAL authn works
    # on these OSes. Maybe getpeereid() calls LOCAL_PEERCRED?
    'freebsd',  # NB: doesn’t work w/ socketpair()
    'darwin',

    # 'openbsd', ??? Still trying to test.

    # No way to pass credentials via UNIX socket,
    # so let’s just send EXTERNAL and see what happens.
    # It’ll likely just fail over to DBUS_COOKIE_SHA1.
    'cygwin',
    'mswin32',
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

        # As of this writing it seems FreeBSD and DragonflyBSD do require
        # Socket::MsgHdr, even though they both have LOCAL_PEERCRED which
        # should take care of that.
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
