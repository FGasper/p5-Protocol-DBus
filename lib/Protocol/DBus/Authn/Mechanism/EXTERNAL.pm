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

        # On Linux this module doesn’t need to make any special
        # effort to send credentials because the server will request them on
        # its own, and SO_PASSCRED works independently of the client anyway.
        # (Although Linux only sends the real credentials, we’ll send the
        # EUID in the AUTH line.)
        #
        # As it happens, though, the reference implementation uses
        # SO_PEERCRED on Linux anyway, as well as OpenBSD. It also
        # tries LOCAL_PEEREID for NetBSD, getpeerucred() for Solaris,
        # and getpeereid() as a fallback. Only FreeBSD & DragonflyBSD
        # appear to be expected to send SCM_CREDS directly, even though
        # those OSes do have LOCAL_PEERCRED which should work.
        #
        my $can_skip_msghdr = eval { Socket::SO_PEERCRED(); 1 };
        $can_skip_msghdr ||= eval { Socket::LOCAL_PEEREID(); 1 };

        $self->{'_must_send_initial'} = !$can_skip_msghdr;
    }

    return $self->{'_must_send_initial'};
}

sub send_initial {
    my ($self, $s) = @_;

    eval { require Socket::MsgHdr; 1 } or do {
        die "Socket::MsgHdr appears to be needed for EXTERNAL authn but failed to load: $@";
    };

    my $msg = Socket::MsgHdr->new( buf => "\0" );

    # The kernel should fill in the payload.
    $msg->cmsghdr( Socket::SOL_SOCKET(), Socket::SCM_CREDS(), "\0" x 64 );

    local $!;
    my $ok = Socket::MsgHdr::sendmsg($s, $msg, Socket::MSG_NOSIGNAL() );

    if (!$ok && !$!{'EAGAIN'}) {
        die "sendmsg($s): $!";
    }

    return $ok;
}

1;
