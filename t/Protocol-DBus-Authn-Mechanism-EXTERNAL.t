use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

use Socket;

BEGIN {
    eval { require Socket::MsgHdr };
}

if (Socket::MsgHdr->can('new')) {
    socketpair my $cln, my $srv, Socket::AF_UNIX, Socket::SOCK_STREAM, 0;

    my $cred_opt = grep { Socket->can($_) } qw( SO_PASSCRED LOCAL_CREDS );

    if ($cred_opt) {
        setsockopt $srv, Socket::SOL_SOCKET, Socket->$cred_opt(), 1;
    }
    else {
        note "$^O doesn’t appear to support receiving ancillary credentials.";
    }

    my $client_pid = fork or do {
        die "fork(): $!" if !defined $pid;

        my $ok = eval {
            close $srv;

            my $authn = Protocol::DBus::Authn->new(
                socket => $cln,
                mechanism => 'EXTERNAL',
            );

            $authn->go();

            1;
        };
        warn if !$ok;

        exit( $ok ? 0 : 1);
    };

    close $cln;

    my $dbsrv = t::MockDBusServer->new($srv);

    my $c1 = $dbsrv->getc();
    is( $c1, "\0", 'NUL byte sent first' );

    cmp_deeply(
        [ $dbsrv->harvest_control() ],
        [
            [ Socket::SOL_SOCKET(), $cred_opt, ignore() ],
        ],
        'credentials sent with first byte',
    );

    my $line = $dbsrv->get_line();

    my $CRLF = "\x0d\x0a";

    my $ruid_hex = unpack('H*', $<);

    is(
        $line,
        "AUTH EXTERNAL $ruid_hex$CRLF",
        'first line',
    );

    kill 'TERM', $client_pid;
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

        recvmsg( $self->{'_s'}, $rmsg ) or die "recvmsg(): $!";

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

        recvmsg( @{$self}{'_s', '_msg'} ) or die "recvmsg(): $!";

        $self->{'_in'} .= $self->{'_msg'}->buf();

        $self->_consume_control( $self->{'_msg'} );
    }

    return substr( $self->{'_in'}, 0, 2 + $crlf_at, q<>);
}

sub harvest_control {
    my ($self) = @_;

    return splice @{ $self->{'_ctl'} };
}

sub _consume_control {
    my ($self, $msg) = @_;

    if ($msg->control()) {
        push @{ $self->{'_ctl'} }, [ $msg->control() ];
    }

    return;
}

1;
