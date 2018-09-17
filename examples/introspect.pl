#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Socket;

# bug in this module: it breaks when loaded dynamically
use Socket::MsgHdr;

use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Protocol::DBus::Authn;
use Protocol::DBus::Message;

$| = 1;

my $buf = q<>;

my $dest = $ENV{'DBUS_SESSION_BUS_ADDRESS'} or die 'No DBUS_SESSION_BUS_ADDRESS!';

$dest =~ s<\Aunix:path=><> or die "Invalid session bus address: $dest";

socket my $s, Socket::AF_UNIX(), Socket::SOCK_STREAM(), 0;
connect $s, Socket::pack_sockaddr_un($dest);

my $authn = Protocol::DBus::Authn->new(
    socket => $s,
    mechanism => 'EXTERNAL',
);

$authn->negotiate_unix_fd()->go();

alarm 5;

my $msg = Protocol::DBus::Message->new(
    type => 'METHOD_CALL',
    serial => 1,
    hfields => [
        [ PATH => '/org/freedesktop/DBus' ],
        [ INTERFACE => 'org.freedesktop.DBus' ],
        [ DESTINATION => 'org.freedesktop.DBus' ],
        [ MEMBER => 'Hello' ],
    ],
);

syswrite $s, ${ $msg->to_string_le() };

while (1) {
    $msg = _get_msg();
    last if $msg->type_is('SIGNAL');
}

$msg = Protocol::DBus::Message->new(
    type => 'METHOD_CALL',
    serial => 2,
    hfields => [
        [ PATH => '/org/freedesktop/DBus' ],
        [ INTERFACE => 'org.freedesktop.DBus.Introspectable' ],
        [ DESTINATION => 'org.freedesktop.DBus' ],
        [ MEMBER => 'Introspect' ],
    ],
);

syswrite $s, ${ $msg->to_string_le() };

while (1) {
    $msg = _get_msg();

    if (!$msg->type_is('SIGNAL')) {
        last if $msg->serial() == 3;
    }
}

sub _get_msg {
    my $msg;
    while ($buf || sysread $s, $buf, 32768, length($buf)) {
        $msg = Protocol::DBus::Message->parse(\$buf);
        if ($msg) {
            print Dumper $msg;
            return $msg;
        }
    }

    die "Empty read?";
}
