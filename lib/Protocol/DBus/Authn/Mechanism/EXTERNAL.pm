package Protocol::DBus::Authn::Mechanism::EXTERNAL;

use strict;
use warnings;

use parent 'Protocol::DBus::Authn::Mechanism';

sub INITIAL_RESPONSE { unpack 'H*', $> }

sub AFTER_OK {
    my ($self) = @_;

    return if !Socket::MsgHdr->can('new');

    return if $self->{'_skip_unix_fd'};

    return (
        [ 0 => 'NEGOTIATE_UNIX_FD' ],
        [ 1 => \&_consume_agree_unix_fd ],
    );
}

sub new {
    my $self = $_[0]->SUPER::new(@_[ 1 .. $#_ ]);

    $self->{'_skip_unix_fd'} = 1 if !Socket->can('SCM_RIGHTS');

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

sub send_initial {
    my ($class, $s) = @_;

    my $ok = syswrite $s, "\0";
    if (!$ok && !$!{'EAGAIN'}) {
        die "write($s): $!";
    }

    return $ok;
}

1;
