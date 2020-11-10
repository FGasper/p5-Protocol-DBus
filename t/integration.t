#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

use Protocol::DBus::Authn::Mechanism::EXTERNAL ();

use File::Which;

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
    my $bin = File::Which::which('dbus-run-session') or do {
        skip 'No dbus-run-session', 1;
    };

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
    skip 'No usable dbus-run-session', 1 if !$dbus_run_session_bin;

    my $can_anyevent = readpipe qq<$^X -e'print eval { require AnyEvent; 1 } || 0'>;
    skip 'No usable AnyEvent', 1 if !$can_anyevent;

    my $run = readpipe( qq[$dbus_run_session_bin -- $^X @incargs -MProtocol::DBus::Client::AnyEvent -MAnyEvent -e'my \$dbus = Protocol::DBus::Client::AnyEvent::system(); my \$cv = AnyEvent->condvar(); \$dbus->initialize()->finally(\$cv); \$cv->recv(); print "ok"'] );

    is($run, 'ok', 'AnyEvent did initialize()');
}

SKIP: {
    skip 'No usable dbus-run-session', 1 if !$dbus_run_session_bin;

    my $can_ioasync = readpipe qq<$^X -e'print eval { require IO::Async::Loop; 1 } || 0'>;
    skip 'No usable IO::Async', 1 if !$can_ioasync;

    my $run = readpipe( qq[$dbus_run_session_bin -- $^X @incargs -MProtocol::DBus::Client::IOAsync -MIO::Async::Loop -e'my \$loop = IO::Async::Loop->new(); my \$dbus = Protocol::DBus::Client::IOAsync::system(\$loop); \$dbus->initialize()->finally( sub { \$loop->stop() } ); \$loop->run(); print "ok"'] );

    is($run, 'ok', 'IO::Async did initialize()');
}

SKIP: {
    skip 'No usable dbus-run-session', 1 if !$dbus_run_session_bin;

    my $can_mojo = readpipe qq<$^X -e'print eval { require Mojo::IOLoop; 1 } || 0'>;
    skip 'No usable Mojo::IOLoop', 1 if !$can_mojo;

    my $run = readpipe( qq[$dbus_run_session_bin -- $^X @incargs -MProtocol::DBus::Client::Mojo -MMojo::IOLoop -e'my \$dbus = Protocol::DBus::Client::Mojo::system(); my \$p = \$dbus->initialize(); \$p->wait(); print "ok"'] );

    is($run, 'ok', 'Mojo did initialize()');
}

done_testing();

