use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;
use Test::Deep;

use Socket;

use FindBin;
use lib "$FindBin::Bin/lib";
use ClientServer;

use Protocol::DBus::Authn;

do {
    my $pid = fork or do {
        require Socket::MsgHdr;
        exit;
    };

    local $?;
    waitpid $pid, 0;

    BAIL_OUT('Need Socket::MsgHdr!') if $?;
};

my @tests = (
    {
        label => 'with unix fd',
        client => sub {
            my ($cln) = @_;

            require Socket::MsgHdr;

            my $authn = Protocol::DBus::Authn->new(
                socket => $cln,
                mechanism => 'EXTERNAL',
            );

            $authn->go();
        },
        server => sub {
            my ($dbsrv) = @_;

            my @ctl = $dbsrv->harvest_control();

            cmp_deeply(
                \@ctl,
                [
                    [ Socket::SOL_SOCKET(), ignore(), ignore() ],
                ],
                'credentials sent with first byte',
            ) or diag explain \@ctl;

            my $line = $dbsrv->get_line();

            my $ruid_hex = unpack('H*', $<);

            is(
                $line,
                "AUTH EXTERNAL $ruid_hex",
                'first line',
            );

            $dbsrv->send_line('OK 1234deadbeef');

            $line = $dbsrv->get_line();

            is( $line, 'NEGOTIATE_UNIX_FD', 'attempt to negotiate' );

            $dbsrv->send_line('AGREE_UNIX_FD');

            $line = $dbsrv->get_line();

            is( $line, 'BEGIN', 'last line: BEGIN' );
        },
    },
    {
        label => 'without unix fd',
        client => sub {
            my ($cln) = @_;

            my $authn = Protocol::DBus::Authn->new(
                socket => $cln,
                mechanism => 'EXTERNAL',
            );

            $authn->go();
        },
        server => sub {
            my ($dbsrv) = @_;

            my @ctl = $dbsrv->harvest_control();

            cmp_deeply(
                \@ctl,
                [
                    [ Socket::SOL_SOCKET(), ignore(), ignore() ],
                ],
                'credentials sent with first byte',
            ) or diag explain \@ctl;

            my $line = $dbsrv->get_line();

            my $ruid_hex = unpack('H*', $<);

            is(
                $line,
                "AUTH EXTERNAL $ruid_hex",
                'first line',
            );

            $dbsrv->send_line('OK 1234deadbeef');

            $line = $dbsrv->get_line();

            is( $line, 'BEGIN', 'last line: BEGIN' );
        },
    },
);

if (!ClientServer::server_credentials_opt()) {
    plan skip_all => 'Need socket credential receptor logic for this test!';
}

ClientServer::do_tests(@tests);

done_testing();

1;
