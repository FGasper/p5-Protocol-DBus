package Protocol::DBus::MsgHdr;

use strict;
use warnings;

sub load_for_fds {
    my $dollar_at = $@;
    eval { require Socket::MsgHdr } or do {
        die "Socket::MsgHdr is required to send/receive filehandles but failed to load: $@";
    };
    $@ = $dollar_at;

    return;
}

1;
