package Protocol::DBus::MsgHdr;

use strict;
use warnings;

sub load {
    require Socket;

    require Socket::MsgHdr;
    if (!Socket::MsgHdr->can('buf')) {
        die 'Socket::MsgHdr has to be loaded at compile time. Please harass Socket::MsgHdr’s maintainer to fix this: https://rt.cpan.org/Public/Bug/Display.html?id=127115';
    }

    return;
}

1;
