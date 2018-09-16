#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Socket::MsgHdr;

use Protocol::DBus::Authn;
use Protocol::DBus::Message;

use Socket;

my $dest = $ENV{'DBUS_SESSION_BUS_ADDRESS'} or die 'No DBUS_SESSION_BUS_ADDRESS!';

$dest =~ s<\Aunix:path=><> or die "Invalid session bus address: $dest";

socket my $s, Socket::AF_UNIX(), Socket::SOCK_STREAM(), 0;
connect $s, Socket::pack_sockaddr_un($dest);

my $authn = Protocol::DBus::Authn->new(
    socket => $s,
    mechanism => 'EXTERNAL',
);

$authn->go();

my $msg = Protocol::DBus::Message->new(
    type => 'METHOD_CALL',
    serial => 1,
    hfields => [
        [ PATH => '/org/freedesktop/NetworkManager' ],
        [ INTERFACE => '/org/freedesktop/NetworkManager' ],
        [ DESTINATION => '/org/freedesktop/NetworkManager' ],
        [ MEMBER => 'Introspect' ],
    ],
);

syswrite $s, $msg->to_string_le();

my $buf = q<>;
my $msg;
while (sysread $s, $buf, 32768, length($buf)) {
    $msg = Protocol::DBus::Message->parse($buf);
    last if $msg;
}

use Data::Dumper;
print STDERR Dumper $msg;
