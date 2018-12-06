package MockDBusServer;

use strict;
use warnings;

my $CRLF;
BEGIN {
    $CRLF = "\x0d\x0a";
}

#----------------------------------------------------------------------

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
