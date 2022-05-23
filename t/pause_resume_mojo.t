#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::FailWarnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use DBusSession;

SKIP: {
    skip 'No Mojo::IOLoop!', 1 if !eval { require Mojo::IOLoop };
    skip 'No Mojo::Promise!', 1 if !eval { require Mojo::Promise };
    skip 'Loop can’t timer()!', 1 if !Mojo::IOLoop->can('timer');

    DBusSession::skip_if_lack_needed_socket_msghdr(1);

    DBusSession::get_bin_or_skip();

    my $session = DBusSession->new();

    require Protocol::DBus::Client::Mojo;

    my $dbus = eval {
        Protocol::DBus::Client::Mojo::login_session();
    } or skip "Can’t open login session: $@";

    my $on_signal_cr;
    $dbus->on_signal(
        sub {
            $on_signal_cr->(shift) if $on_signal_cr;
        },
    );

    my @received_after_resume;

    my $bus_name;

    $dbus->initialize()->then(
        sub {
            my $messenger = shift;

            $bus_name = $messenger->get_unique_bus_name();

            return Mojo::Promise->new( sub {
                my ($y, $n) = @_;

                my $timer_id = Mojo::IOLoop->timer(
                    5,
                    sub {
                        $n->('timed out');
                    },
                );

                $on_signal_cr = sub {
                    my ($msg) = @_;

                    if ($msg->get_header('PATH') eq '/test/pdb') {
                        diag 'Got sanity-check signal';
                        Mojo::IOLoop->remove($timer_id);
                        $y->($messenger);
                    }
                };

                $messenger->send_signal(
                    path => '/test/pdb',
                    interface => 'test.pdb',
                    member => 'message',
                    destination => $bus_name,   # myself
                )->then(
                    sub {
                        diag 'sent sanity-check signal';
                    },
                );
            } );
        },
    )->then(
        sub {
            my $messenger = shift;

            my @received_while_paused;

            $on_signal_cr = sub {
                diag 'oops! received a message while paused!';
                push @received_while_paused, shift;
            };

            $messenger->pause();
            diag 'paused';

            $messenger->send_signal(
                path => '/test/pdb',
                interface => 'test.pdb',
                member => 'message',
                destination => $bus_name,   # myself
                signature => 's',
                body => ['real message'],
            )->then( sub {
                diag 'sent “real” test message';
            } );

            return Promise::ES6->new( sub {
                my ($y, $n) = @_;

                my $timer_id = Mojo::IOLoop->timer(
                    1,
                    sub {
                        is(
                            "@received_while_paused",
                            q<>,
                            'got nothing while paused',
                        ) or diag explain \@received_while_paused;

                        $y->($messenger);
                    },
                );

                diag 'Waiting to see if pause() works …';
            } );
        },
    )->then(
        sub {
            my $messenger = shift;

            return Promise::ES6->new( sub {
                my ($y, $n) = @_;

                my $timer_id;

                $on_signal_cr = sub {
                    Mojo::IOLoop->remove($timer_id);
                    push @received_after_resume, shift;
                    $y->();
                };

                diag 'resuming';
                $messenger->resume();
                diag 'resumed';

                $timer_id = Mojo::IOLoop->timer(
                    5,
                    sub {
                        $n->('timeout waiting for D-Bus signal!');
                    },
                );
            } );
        },
    )->wait();

    cmp_deeply(
        \@received_after_resume,
        [ Isa('Protocol::DBus::Message') ],
        'received signal after resume',
    );
}

done_testing;

1;
