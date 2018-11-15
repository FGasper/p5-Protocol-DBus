package Protocol::DBus::WriteMsg;

use strict;
use warnings;

use parent qw( IO::Framed::Write );

use Socket;
use Socket::MsgHdr;

my %obj_fh;
my %fh_obj;

sub new {
    my ($class, $out_fh) = @_;

    my $self = $class->SUPER::new($out_fh);

    $fh_obj{$out_fh} = $self;
    $obj_fh{$self} = $out_fh;

    return $self;
}

sub DESTROY {
    my ($self) = @_;

    my $fh = delete $obj_fh{$self};
    delete $fh_obj{$fh};

    return;
}

sub enqueue_message {
    my ($self, $buf_sr, $fds_ar) = @_;

    push @{ $self->{'_message_fds'} }, ($fds_ar && @$fds_ar) ? $fds_ar : undef;

    $self->write(
        $$buf_sr,
        sub {
            shift @{ $self->{'_message_fds'} };
        },
    );

    return $self;
}

# Receives ($fh, $buf)
sub WRITE {

    # Only use sendmsg if we actually need to.
    if (my $fds_ar = $fh_obj{ $_[0] }{'_message_fds'}[0]) {
        my $msg = Socket::MsgHdr->new( buf => $_[1] );

        $msg->cmsghdr(
            Socket::SOL_SOCKET(), Socket::SCM_RIGHTS(),
            pack( 'I!*', @$fds_ar ),
        );

        my $bytes = Socket::MsgHdr::sendmsg( $_[0], $msg );

        if ($bytes) {
            undef $fh_obj{ $_[0] }{'_message_fds'}[0];
        }

        return $bytes;
    }

    goto &IO::Framed::Write::WRITE;
}

1;
