#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

use Protocol::DBus::Client;

my $client = eval {
    my $db = Protocol::DBus::Client->system();
    $db->initialize();
    $db;
};

if ($client) {
    ok 1, 'system bus connected!';
}
else {
    diag "system bus not available: $@";

    eval { require File::Which; 1 } or plan skip_all => 'No File::Which';

    my $bin = File::Which::which('dbus-run-session') or do {
        plan skip_all => 'No dbus-run-session';
    };

    system($bin, '--', $^X, '-e1');
    if ($?) {
        plan skip_all => 'dbus-run-session exited nonzero';
    }

    system( $bin, '--', $^X, '-MProtocol::DBus::Client', -e => 'Protocol::DBus::Client->login_session()->initialize()' );
    ok( !$?, 'login session bus connected!' );
}

done_testing();
