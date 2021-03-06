#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Socket;

use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Protocol::DBus::Client;

my $dbus = $> ? Protocol::DBus::Client::login_session() : Protocol::DBus::Client::system();

$dbus->preserve_variant_signatures(1);

$dbus->initialize();

my $got_response;

$dbus->send_call(
    path => '/org/freedesktop/DBus',
    interface => 'org.freedesktop.DBus.Properties',
    destination => 'org.freedesktop.DBus',
    signature => 's',
    member => 'GetAll',
    body => ['org.freedesktop.DBus'],
)->then( sub {
    $got_response = 1;
    print "got getall response\n";
    print Dumper shift;
} );

$dbus->get_message() while !$got_response;
