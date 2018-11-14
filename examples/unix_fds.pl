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

use Protocol::DBus::Client;

my $dbus = Protocol::DBus::Client::system();

$dbus->do_authn();

$dbus->send_call(
    member => 'AddMatch',
    signature => 's',
    destination => 'org.freedesktop.DBus',
    interface => 'org.freedesktop.DBus',
    path => '/org/freedesktop/DBus',
    body => [
       "type='signal'",
    ]
);

my $recv_name;

while (1) {
    my $msg = $dbus->get_message();

    if ($msg->get_header('MEMBER') eq 'NameAcquired') {
        ($recv_name) = @{ $msg->get_body() };
        last;
    }
}

#print "Receive PID $$, name: $recv_name\n";

$dbus->send_call(
    member => 'AddMatch',
    signature => 's',
    destination => 'org.freedesktop.DBus',
    interface => 'org.freedesktop.DBus',
    path => '/org/freedesktop/DBus',
    body => [
       "type='signal'",
    ]
);

my $pid = fork or do {
    my $dbus = Protocol::DBus::Client::system();

    $dbus->do_authn();

    pipe my $r, my $w;

    $dbus->send_signal(
        member => 'AddMatch',  # hey, it works
        signature => 'h',
        destination => $recv_name,
        interface => 'org.freedesktop.DBus',
        path => '/org/freedesktop/DBus',
        body => [$w],
    );

    print "$$ receives: " . <$r>;

    exit;
};

close STDOUT;

while (1) {
    my $msg = $dbus->get_message();

    my ($fh) = $msg->get_body() && @{ $msg->get_body() };
    next if 'GLOB' ne ref $fh;

    syswrite $fh, "Hello from PID $$ at " . localtime . $/;
    last;
}

waitpid $pid, 0;
