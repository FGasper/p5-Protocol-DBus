#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

use Protocol::DBus::Authn::Mechanism::EXTERNAL ();

use File::Which;

use Protocol::DBus::Client;

my $no_msghdr_needed = grep { $^O eq $_ } @Protocol::DBus::Authn::Mechanism::EXTERNAL::_OS_NO_MSGHDR_LIST;

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
        if ($no_msghdr_needed) {
            ok( $client, 'dbus-send worked, and system()' );
        }
        else {
            my $smh_loaded_yn = $INC{'Socket/MsgHdr.pm'} ? 'y' : 'n';

            my $msg;

            if ($client) {
                $msg = "system() worked";
            }
            else {
                $msg = "system() failed ($@)";
            }

            skip "$msg (S::MH loaded? $smh_loaded_yn)", 1;
        }
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

    my $loaded_smh = readpipe( qq[$bin -- $^X -MProtocol::DBus::Client -e 'Protocol::DBus::Client->login_session()->initialize(); print \$INC{"Socket/MsgHdr.pm"} ? "y" : "n"'] );

    if ($no_msghdr_needed) {
        ok( !$?, 'login session bus connected!' ) or diag $env;
    }
    else {
        my $msg;

        if ($?) {
            $msg = "login_session() failed";
        }
        else {
            $msg = "login_session() worked";
        }

        skip "$msg (S::MH loaded? $loaded_smh)", 1;
    }
}

#----------------------------------------------------------------------

done_testing();
