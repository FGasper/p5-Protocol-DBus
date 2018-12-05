use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;
use Test::Deep;
use Test::SharedFork;

use Socket;

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

my ($cred_opt) = grep { Socket->can($_) } qw( SO_PASSCRED LOCAL_CREDS );

if ($cred_opt) {
    $cred_opt = Socket->$cred_opt();
}
else {
    BAIL_OUT('Need socket credential receptor logic!');
}

for my $t (@tests) {
    alarm 600;

    my ($label, $client_cr, $server_cr) = @{$t}{'label', 'client', 'server'};

    note '-----------------------';
    note "TEST: $label";

    socketpair my $cln, my $srv, Socket::AF_UNIX, Socket::SOCK_STREAM, 0;

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

            setsockopt $srv, Socket::SOL_SOCKET, $cred_opt, 1;

            my $dbsrv = t::MockDBusServer->new($srv);

            my $c1 = $dbsrv->getc();
            is( $c1, "\0", 'NUL byte sent first' );

            $server_cr->($dbsrv);

            kill 'TERM', $client_pid;
        };
        warn if !$ok;

        exit( $ok ? 0 : 1);
    };

    waitpid $client_pid, 0;
    waitpid $server_pid, 0;
}

done_testing();

#----------------------------------------------------------------------

package t::MockDBusServer;

my $CRLF;
BEGIN {
    $CRLF = "\x0d\x0a";
}

sub new {
    my ($class, $socket) = @_;

    my $rmsg = Socket::MsgHdr->new(
        buflen => 1024,
        controllen => 512,
    );

    return bless { _s => $socket, _msg => $rmsg, _in => q<> }, $class;
}

sub send_line {
    my ($self, $payload) = @_;

    syswrite $self->{'_s'}, ( $payload . $CRLF );
}

sub getc {
    my ($self) = @_;

    my $c;

    if (length $self->{'_in'}) {
        $c = substr( $self->{'_in'}, 0, 1, q<> );
    }
    else {
        my $rmsg = Socket::MsgHdr->new(
            buflen => 1,
            controllen => 512,
        );

        $c = $rmsg->buf();

        Socket::MsgHdr::recvmsg( $self->{'_s'}, $rmsg ) or die "recvmsg(): $!";

        $self->_consume_control( $rmsg );
    }

    return $c;
}

sub get_line {
    my ($self) = @_;

    my $crlf_at;

    while (1) {
        $crlf_at = index( $self->{'_in'}, $CRLF );

        last if -1 != $crlf_at;

        my $msg = $self->{'_msg'};

        Socket::MsgHdr::recvmsg( $self->{'_s'}, $msg ) or die "recvmsg(): $!";

        $self->{'_in'} .= $msg->buf();

        $self->_consume_control( $msg );
    }

    return substr(
        substr( $self->{'_in'}, 0, 2 + $crlf_at, q<>),
        0,
        -2,
    );
}

sub harvest_control {
    my ($self) = @_;

    return splice @{ $self->{'_ctl'} };
}

sub _consume_control {
    my ($self, $msg) = @_;

    if ($msg->control()) {
        push @{ $self->{'_ctl'} }, [ $msg->cmsghdr() ];
    }

    return;
}

1;
