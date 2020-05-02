#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

SKIP: {
    skip 'No AnyEvent!' if !eval { require AnyEvent };

    require Protocol::DBus::Client::AnyEvent;

    my $dbus = Protocol::DBus::Client::AnyEvent::login_session();

    my $cv = AnyEvent->condvar();

    $dbus->on_failure( sub {
        like( $_[0], qr<.>, 'failure happens' );
        $cv->();
    } );

    my $timer = AnyEvent->timer(
        after => 5,
        cb => sub {
            fail 'timed out';
            $cv->();
        },
    );

    $dbus->initialize()->then(
        sub {
            my $msgr = shift;

            # NOT to be done in production. This can change at any time.
            my $dbus = $msgr->_dbus();

            my $fileno = $dbus->fileno();
            open my $fh, "+>&=$fileno" or die "failed to take fd $fileno: $!";

            syswrite $fh, 'z';

            $msgr->send_signal(
                path => '/what/ever',
                interface => 'what.ever',
                member => 'member',
            )->then(
                sub { print "signal sent\n" },
                sub { print "signal NOT sent\n" },
            );
        },
        sub {
            $cv->();
            skip "Failed to initialize: $_[0]";
        },
    );

    $cv->recv();
};

done_testing;

1;
