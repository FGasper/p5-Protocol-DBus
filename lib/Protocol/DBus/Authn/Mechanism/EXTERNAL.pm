package Protocol::DBus::Authn::Mechanism::EXTERNAL;

use strict;
use warnings;

use parent 'Protocol::DBus::Authn::Mechanism';

use Socket ();
use Socket::MsgHdr ();

sub INITIAL_RESPONSE { unpack 'H*', $> }

sub send_initial {
    my ($class, $s) = @_;

    my $msg = Socket::MsgHdr->new( buf => "\0" );

    my $ok;

    if (Socket->can('SCM_CREDENTIALS')) {
        my $ucred = pack( 'I*', $$, $>, (split m< >, $))[0]);

        $msg->cmsghdr( Socket::SOL_SOCKET(), Socket::SCM_CREDENTIALS(), $ucred );

        local $!;
        $ok = Socket::MsgHdr::sendmsg($s, $msg, Socket::MSG_NOSIGNAL() );

        if (!$ok && !$!{'EAGAIN'}) {
            die "sendmsg($s): $!";
        }
    }
    else {
        die "Unsupported OS: $^O";
    }

    return $ok;
}

1;
