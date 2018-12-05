#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use_ok('Protocol::DBus::Address');

my @tests = (
    [
        'unix:path=/tmp/dbus-test;unix:path=/tmp/dbus-test2',
        [
            {
                transport => 'unix',
                path => '/tmp/dbus-test',
            },
            {
                transport => 'unix',
                path => '/tmp/dbus-test2',
            },
        ],
    ],
    [
        'unix:path=/tmp/dbus-XNYkn7CovF,guid=fff528e7416a38184c876a3a5c076340',
        [
            {
                transport => 'unix',
                path => '/tmp/dbus-XNYkn7CovF',
                guid => 'fff528e7416a38184c876a3a5c076340',
            },
        ],
    ],
);

for my $t (@tests) {
    my @out = Protocol::DBus::Address::parse( $t->[0] );

    is_deeply(
        \@out,
        $t->[1],
        $t->[0],
    ) or diag explain \@out;
}

done_testing();
