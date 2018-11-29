package Protocol::DBus::WriteMsg;

use strict;
use warnings;

use parent qw( IO::Framed::Write );

use Protocol::DBus::MsgHdr;

my %fh_fds;

sub DESTROY {
    my ($self) = @_;

    my $fh = delete $fh_fds{ $self->get_write_fh() };

    return;
}

sub enqueue_message {
    my ($self, $buf_sr, $fds_ar) = @_;

    push @{ $fh_fds{$self->get_write_fh()} }, ($fds_ar && @$fds_ar) ? $fds_ar : undef;

    $self->write(
        $$buf_sr,
        sub {

            # We’re done with the message, so we remove the FDs entry,
            # which by here should be undef.
            shift @{ $fh_fds{$self->get_write_fh()} };
        },
    );

    return $self;
}

sub _load_socket_msghdr {

    # Some older Perls have a problem with `local $@`.
    my $dollar_at = $@;
    eval { Protocol::DBus::MsgHdr::load(); 1 } or do {
        die "Socket::MsgHdr (required to pass filehandles) failed to load: $@";
    };
    $@ = $dollar_at;

    if (!Socket->can('SCM_RIGHTS')) {
        die "Your OS ($^O) cannot pass filehandles via sockets!";
    }

    return;
}

# Receives ($fh, $buf)
sub WRITE {

    # Only use sendmsg if we actually need to.
    if (my $fds_ar = $fh_fds{ $_[0] }[0]) {
        _load_socket_msghdr() if !$INC{'Socket/MsgHdr.pm'};

        my $msg = Socket::MsgHdr->new( buf => $_[1] );

        $msg->cmsghdr(
            Socket::SOL_SOCKET(), Socket::SCM_RIGHTS(),
            pack( 'I!*', @$fds_ar ),
        );

        my $bytes = Socket::MsgHdr::sendmsg( $_[0], $msg );

        # NOTE: This assumes that, on an incomplete write, the ancillary
        # data (i.e., the FDs) will have been sent, and there is no need
        # to resend. That appears to be the case on Linux and MacOS, but
        # I can’t find any actual documentation to that effect. <shrug>
        if ($bytes) {
            undef $fh_fds{ $_[0] }[0];
        }

        return $bytes;
    }

    goto &IO::Framed::Write::WRITE;
}

1;
