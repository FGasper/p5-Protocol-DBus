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

use Carp::Always;

$dbus->blocking(0);

my $fileno = $dbus->fileno();

# You can use whatever polling method you prefer;
# the following is quick and easy:
vec( my $mask, $fileno, 1 ) = 1;

while (!$dbus->do_authn()) {
    if ($dbus->authn_pending_send()) {
        select( undef, my $wout = $mask, undef, undef );
    }
    else {
        select( my $rout = $mask, undef, undef, undef );
    }
}

#----------------------------------------------------------------------

my $got_response;

$dbus->send_call(
    path => '/org/freedesktop/DBus',
    interface => 'org.freedesktop.DBus.Properties',
    destination => 'org.freedesktop.DBus',
    signature => 's',
    member => 'GetAll',
    body => \'org.freedesktop.DBus',
    on_return => sub {
        $got_response = 1;
        print "got getall response\n";
        print Dumper shift;
    },
);

while (!$got_response) {
    my $win = $dbus->pending_send() || q<>;
    $win &&= $mask;

    select( my $rout = $mask, $win, undef, undef );
    $dbus->send_receive();
}
