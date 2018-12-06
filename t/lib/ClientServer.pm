package ClientServer;

use strict;
use warnings;

use Test::More;
use Test::SharedFork;

use Socket;

use MockDBusServer;

sub do_tests {
    my (@tests) = @_;

    for my $t (@tests) {
        my ($label, $client_cr, $server_cr) = @{$t}{'label', 'client', 'server'};

        note '-----------------------';
        note "TEST: $label";

        _run( $client_cr, $server_cr );
    }

    return;
}

sub can_socket_msghdr {
    return do {
        my $pid = fork or do {
            exit( eval { require Socket::MsgHdr; 1 } ? 0 : 1 );
        };

        waitpid $pid, 0;
        !$?;
    };
}

sub _run {
    my ($client_cr, $server_cr) = @_;

    socketpair my $cln, my $srv, Socket::AF_UNIX, Socket::SOCK_STREAM, 0;

    local $| = 1;

    my $client_pid = fork or do {
        my $ok = eval {
            close $srv;

            $client_cr->($cln);

            sleep 60;

            1;
        };
        warn if !$ok;

        exit( $ok ? 0 : 1);
    };

    my $server_pid = fork or do {
        my $ok = eval {
            require Socket::MsgHdr;

            close $cln;

            my $dbsrv = MockDBusServer->new($srv);

            my $c1 = $dbsrv->getc();
            is( $c1, "\0", 'NUL byte sent first' );

            $server_cr->($dbsrv);

            kill 'TERM', $client_pid;
        };
        warn if !$ok;

        exit( $ok ? 0 : 1);
    };

    my %wait = ( $client_pid => 'client', $server_pid => 'server' );

    alarm 30;

    while (%wait) {
        for my $pid (keys %wait) {
            if ( waitpid $pid, 1 ) {
                diag "PID $pid ($wait{$pid}) ended.";
                delete $wait{$pid};
            }
        }

        select undef, undef, undef, 0.1;
    }

    alarm 0;

    return;
}

1;
