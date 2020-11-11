#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

use Protocol::DBus::Authn::Mechanism::EXTERNAL ();

use File::Which;

use FindBin;
use lib "$FindBin::Bin/lib";
use DBusSession;

use Protocol::DBus::Client;

{
    #----------------------------------------------------------------------
    # This test can’t work without XS because the location of D-Bus’s
    # system socket is hard-coded in libdbus at compile time.
    #
    # It’s still a useful diagnostic, though.
    #----------------------------------------------------------------------

    my $dbus_send = File::Which::which('dbus-send');

    diag( "dbus-send: " . ($dbus_send || '(none)') );

    if ($dbus_send) {
        system($dbus_send, '--type=method_call', '--system', '--dest=org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus.Properties.GetAll', 'string:org.freedesktop.DBus');

        diag( "dbus-send --system worked? " . ($? ? 'no' : 'yes') );
    }

    my $client = eval {
        local $SIG{'__WARN__'} = sub { diag shift() };

        my $db = Protocol::DBus::Client::system();
        $db->initialize();
        $db;
    };
    my $err = $@;

    diag( "Client::system() worked? " . ($client ? 'yes' : 'no') );
    diag $err if !$client;

    diag( "Socket::MsgHdr loaded? " . ($INC{'Socket/MsgHdr.pm'} ? 'yes' : 'no') );
}

#----------------------------------------------------------------------

# Ensure that we test with the intended version of Protocol::DBus …
my @incargs = map { "-I$_" } @INC;

my $dbus_run_session_bin;

SKIP: {
    my $bin = DBusSession::get_bin_or_skip();

    my $env = readpipe("$bin -- $^X -MData::Dumper -e '\$Data::Dumper::Sortkeys = 1; print Dumper \\\%ENV'");
    if ($?) {
        skip 'dbus-run-session exited nonzero', 1;
    }

    $dbus_run_session_bin = $bin;

    my $loaded_smh = readpipe( qq[$bin -- $^X @incargs -MProtocol::DBus::Client -e 'Protocol::DBus::Client::login_session()->initialize(); print \$INC{"Socket/MsgHdr.pm"} ? "y" : "n"'] );

    my $no_msghdr_needed = grep { $^O eq $_ } @Protocol::DBus::Authn::Mechanism::EXTERNAL::_OS_NO_MSGHDR_LIST;

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

SKIP: {
    skip 'No usable dbus-run-session', 3 if !$dbus_run_session_bin;

    my $sess = DBusSession->new();

    _test_anyevent();
    _test_ioasync();
    _test_mojo();
}

sub _test_anyevent {
    SKIP: {
        skip 'No usable AnyEvent', 1 if !eval { require AnyEvent };

        diag "Testing AnyEvent …";

        require Protocol::DBus::Client::AnyEvent;

        my $err = eval {
            my $dbus = Protocol::DBus::Client::AnyEvent::login_session();

            my $cv = AnyEvent->condvar();
            $dbus->initialize()->finally($cv);
            $cv->recv();
        };

        ok( !$err, 'AnyEvent can initialize()' );
    }
}

sub _test_ioasync {
    SKIP: {
        skip 'No usable IO::Async', 1 if !eval { require IO::Async::Loop };

        diag "Testing IO::Async …";

        require Protocol::DBus::Client::IOAsync;

        my $err = eval {
            my $loop = IO::Async::Loop->new();
            my $dbus = Protocol::DBus::Client::IOAsync::login_session($loop);

            $dbus->initialize()->finally( sub { $loop->stop() } );
            $loop->run();
        };

        ok( !$err, 'IO::Async can initialize()' );
    }
}

sub _test_mojo {
    SKIP: {
        skip 'No usable Mojo', 1 if !eval { require Mojo::IOLoop };

        diag "Testing Mojo …";

        require Protocol::DBus::Client::Mojo;

        my $err = eval {
            my $dbus = Protocol::DBus::Client::Mojo::login_session();

            $dbus->initialize()->wait();
        };

        ok( !$err, 'Mojo can initialize()' );
    }
}

done_testing();
