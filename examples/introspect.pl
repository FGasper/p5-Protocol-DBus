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
