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

ClientServer::do_tests(@tests);

done_testing();

1;
