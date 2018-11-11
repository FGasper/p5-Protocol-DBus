#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Protocol::DBus;
use Protocol::DBus::Client;

# https://rt.cpan.org/Public/Bug/Display.html?id=127115
use Socket::MsgHdr;

my $dbus = Protocol::DBus::Client::system();

$dbus->do_authn();

$dbus->get_message();

$dbus->send_call(
    member => 'CreateTransaction',
    signature => '',
    path => '/org/freedesktop/PackageKit',
    destination => 'org.freedesktop.PackageKit',
    interface => 'org.freedesktop.PackageKit',
);

my $trans_path = shift @{$dbus->get_message()->get_body()};

$dbus->send_call(
    member => 'AddMatch',
    signature => 's',
    destination => 'org.freedesktop.DBus',
    interface => 'org.freedesktop.DBus',
    path => '/org/freedesktop/DBus',
    body => [
       "path='$trans_path'"
    ]
);

$dbus->send_call(
    member => 'GetPackages',
    signature => 't',
    path => $trans_path,
    destination => 'org.freedesktop.PackageKit',
    interface => 'org.freedesktop.PackageKit.Transaction',
    body => [ 2 ],
);

while (1) {
  my $msg = $dbus->get_message();

  print Dumper $msg->get_body();

  if ($msg->get_header('MEMBER') eq 'Finished') {
    last;
  }
}
