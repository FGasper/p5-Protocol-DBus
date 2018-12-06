package Protocol::DBus::Socket;

use strict;
use warnings;

use Socket ();

# NO support for this (POSIX-standard!) constant in macOS or Solaris.
use constant _MSG_NOSIGNAL => eval { Socket::MSG_NOSIGNAL() } || 0;

sub send_nosignal {

    # This is for OSes that don’t define this constant:
    local $SIG{'PIPE'} = 'IGNORE' if !_MSG_NOSIGNAL();

    return send( $_[0], $_[1], $_[2] | _MSG_NOSIGNAL() );
}

sub sendmsg_nosignal {

    # This is for OSes that don’t define this constant:
    local $SIG{'PIPE'} = 'IGNORE' if !_MSG_NOSIGNAL();

    return Socket::MsgHdr::sendmsg( $_[0], $_[1], $_[2] | _MSG_NOSIGNAL() );
}

1;
