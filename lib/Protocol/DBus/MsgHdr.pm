package Protocol::DBus::MsgHdr;

use strict;
use warnings;

sub _load {
    require Socket;

    require Socket::MsgHdr;
    if (!Socket::MsgHdr->can('buf')) {
        die 'Socket::MsgHdr is broken unless loaded at compile time. Please harass Socket::MsgHdr’s maintainer to fix this: https://rt.cpan.org/Public/Bug/Display.html?id=127115';
    }

    return;
}

sub load_for_authn {
    eval { _load() } or do {
        die "Socket::MsgHdr is required to authenticate because this process’s real and effective credentials do not match. Socket::MsgHdr failed to load, though: $@";
    };
    $@ = $dollar_at;

    return;
}

sub load_for_fds {
    eval { _load() } or do {
        die "Socket::MsgHdr is required to send/receive filehandles but failed to load: $@";
    };
    $@ = $dollar_at;

    return;
}

1;
