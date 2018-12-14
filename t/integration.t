#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

use File::Which;

use Protocol::DBus::Client;

my $dbus_send = File::Which::which('dbus-send');

SKIP: {
    my $dbus_send_ok = $dbus_send && do {
        my $out = readpipe("$dbus_send --print-reply --system --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.Properties.GetAll string:org.freedesktop.DBus");

        !$?;
    };

    my $client = eval {
        my $db = Protocol::DBus::Client->system();
        $db->initialize();
        $db;
    };

    if ($dbus_send && $dbus_send_ok) {
        ok( $client, 'dbus-send worked, and system()' );
    }
    else {
        my $reason;

        if ($client) {
            $reason = "dbus-send failed, but system() worked.";
        }
        elsif (!$dbus_send) {
            $reason = "No dbus-send, and system() failed.";
        }
        else {
            $reason = "dbus-send exists but failed, and system() failed.";
        }

        skip $reason, 1;
    }
}

#----------------------------------------------------------------------

SKIP: {
    my $bin = File::Which::which('dbus-run-session') or do {
        skip 'No dbus-run-session', 1;
    };

    my $env = readpipe("$bin -- $^X -MData::Dumper -e '\$Data::Dumper::Sortkeys = 1; print Dumper \\\%ENV'");
    if ($?) {
        skip 'dbus-run-session exited nonzero', 1;
    }

    system( $bin, '--', $^X, '-MProtocol::DBus::Client', -e => 'Protocol::DBus::Client->login_session()->initialize()' );
    ok( !$?, 'login session bus connected' ) or diag $env;
}

#----------------------------------------------------------------------

done_testing();
