package Protocol::DBus::Authn::Mechanism::EXTERNAL;

use strict;
use warnings;

use Protocol::DBus::MsgHdr ();

use parent 'Protocol::DBus::Authn::Mechanism';

sub INITIAL_RESPONSE { unpack 'H*', $> }

sub AFTER_OK {
    my ($self) = @_;

    return if $self->{'_skip_unix_fd'};

    return (
        [ 0 => 'NEGOTIATE_UNIX_FD' ],
        [ 1 => \&_consume_agree_unix_fd ],
    );
}

sub new {
    my $self = $_[0]->SUPER::new(@_[ 1 .. $#_ ]);

    $self->{'_skip_unix_fd'} = 1 if !Socket::MsgHdr->can('new') || !Socket->can('SCM_RIGHTS');

    return $self;
}

sub _consume_agree_unix_fd {
    my ($authn, $line) = @_;

    if ($line eq 'AGREE_UNIX_FD') {
        $authn->{'_can_pass_unix_fd'} = 1;
    }
    elsif (index($line, 'ERROR ') == 0) {
        warn "Server rejected unix fd passing: " . substr($line, 6) . $/;
    }

    return;
}

sub skip_unix_fd {
    my ($self) = @_;

    $self->{'_skip_unix_fd'} = 1;

    return $self;
}

sub must_send_initial {
    my ($self) = @_;

    if (!defined $self->{'_must_send_initial'}) {
        $self->{'_must_send_initial'} = ($< != $>) || (split m< >, $( )[0] != (split m< >, $) )[0] || 0;
    }

    return $self->{'_must_send_initial'};
}

sub send_initial {
    my ($self, $s) = @_;

    # On Linux, the server will have SO_PASSCRED enabled, which causes the
    # kernel to insert SCM_CREDENTIALS into anything that recvmsg() receives,
    # even if the sender didn’t make any effort to include SCM_CREDENTIALS.
    # (The unix(7) man page is NOT clear about this!) Thus, this module
    # doesn’t need to make any special effort to send credentials, and we
    # can just fall back to having Authn.pm send the initial NUL byte.
    #
    # Other OSes are untested.
    return !$self->must_send_initial() || do {
        Protocol::DBus::MsgHdr::load();

        my $msg = Socket::MsgHdr->new( buf => "\0" );

        my $ok;

        if (Socket->can('SCM_CREDENTIALS')) {
            my $ucred = pack( 'I*', $$, $>, (split m< >, $))[0]);

            $msg->cmsghdr( Socket::SOL_SOCKET(), Socket::SCM_CREDENTIALS(), $ucred );

            local $!;
            $ok = Socket::MsgHdr::sendmsg($s, $msg, Socket::MSG_NOSIGNAL() );

            if (!$ok && !$!{'EAGAIN'}) {
                die "sendmsg($s): $!";
            }
        }
        else {
            die "Unsupported OS: $^O";
        }

        $ok;
    };
}

1;
