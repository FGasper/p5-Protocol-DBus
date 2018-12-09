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

use Protocol::DBus::Client;
use Protocol::DBus::Peer;

my $client_cr = sub {
    my ($cln) = @_;

    my $client = Protocol::DBus::Client->new(
        socket => $cln,
        authn_mechanism => 'EXTERNAL',
    );

    print "$$: Sending client authn\n";

    $client->do_authn();

    ok( $client->get_connection_name(), 'connection name is set after authn' );

    print "$$: Done with client authn\n";
};

sub _server_finish_authn {
    my ($dbsrv) = @_;

    my $line = $dbsrv->get_line();

    is( $line, 'BEGIN', 'last line: BEGIN' );

    my $srv = Protocol::DBus::Peer->new( $dbsrv->socket() );

    my $hello = $srv->get_message();

    cmp_deeply(
        $hello,
        all(
            Isa('Protocol::DBus::Message'),
            methods(
                [ type_is => 'METHOD_CALL' ] => 1,
                [ get_header => 'PATH' ] => '/org/freedesktop/DBus',
                [ get_header => 'INTERFACE' ] => 'org.freedesktop.DBus',
                [ get_header => 'MEMBER' ] => 'Hello',
                [ get_header => 'DESTINATION' ] => 'org.freedesktop.DBus',
                get_body => undef,
            ),
        ),
        '“Hello” message sent',
    );

    $srv->send_return(
        $hello,
        destination => ':1.1421',
        sender => 'org.freedesktop.DBus',
        signature => 's',
        body => [':1.1421'],
    );

    return;
}

my @tests = (
    {
        label => 'without unix fd',
        client => $client_cr,
        server => sub {
            my ($dbsrv) = @_;

            print "$$: in server\n";

            my $line = $dbsrv->get_line();

            my $ruid_hex = unpack('H*', $<);

            is(
                $line,
                "AUTH EXTERNAL $ruid_hex",
                'first line',
            );

            $dbsrv->send_line('OK 1234deadbeef');

            _server_finish_authn($dbsrv);
        },
    },
);

if (ClientServer::can_socket_msghdr()) {
    push @tests, {
        label => 'with unix fd',
        client => sub {
            my ($cln) = @_;

            require Socket::MsgHdr;

            $client_cr->($cln);
        },
        server => sub {
            my ($dbsrv, $peer) = @_;

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

            _server_finish_authn($dbsrv);
        },
    };
}
else {
    diag "No Socket::MsgHdr available; can’t test unix FD negotiation.";
}

ClientServer::do_tests(@tests);

done_testing();

1;
