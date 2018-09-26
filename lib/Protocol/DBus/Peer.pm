package Protocol::DBus::Peer;

use strict;
use warnings;

use Call::Context;
use IO::Framed::Write;

use Protocol::DBus::Message;
use Protocol::DBus::Parser;

sub _set_up_peer_io {
    my ($self, $socket) = @_;

    $self->{'_io'} = IO::Framed::Write->new( $socket )->enable_write_queue();
    $self->{'_parser'} = Protocol::DBus::Parser->new( $socket );

    return;
}

sub receive {
    my $msg = $_[0]->{'_parser'}->get_message();

    if (my $serial = $msg->get_header('REPLY_SERIAL')) {
        if (my $cb = delete $_[0]->{'_on_return'}{$serial}) {
            $cb->($msg);
        }
    }

    return $msg;
}

sub flush_write_queue {
    if ($_[0]->{'_io'}->get_write_queue_count()) {
        return $_[0]->{'_io'}->flush_write_queue();
    }

    return 1;
}

sub send_call {
    my ($self, %opts) = @_;

    my $cb = delete $opts{'on_return'};

    my $ret = $self->_send_msg(
        %opts,
        type => 'METHOD_CALL',
    );

    if ($cb) {
        my $serial = $self->{'_last_sent_serial'};
        $self->{'_on_return'}{$serial} = $cb;
    }

    return $ret;
}

sub send_signal {
    my ($self, %opts) = @_;

    return $self->_send_msg(
        %opts,
        type => 'SIGNAL',
    );
}

sub big_endian {
    my ($self) = @_;

    if (@_ > 0) {
        $self->{'_big_endian'} = !!$_[1];
    }

    return !!$self->{'_big_endian'};
}

sub blocking {
    my $self = shift;

    return $_[0]->{'_socket'}->blocking(@_);
}

sub fileno {
    return fileno $_[0]->{'_socket'};
}

sub pending_send {
    return !!$_[0]->{'_io'}->get_write_queue_count();
}

sub _send_msg {
    my ($self, %opts) = @_;

    my ($type, $body_sr, $flags) = delete @opts{'type', 'body', 'flags'};

    my @hargs = map {
        my $k = $_;
        $k =~ tr<a-z><A-Z>;
        ( $k => $opts{$_} );
    } keys %opts;

    my $serial = ++$self->{'_last_sent_serial'};

    my $msg = Protocol::DBus::Message->new(
        type => $type,
        hfields => \@hargs,
        flags => $flags,
        body => $body_sr,
        serial => $serial,
    );

    $self->{'_endian'} ||= 'le';

    $self->{'_io'}->write( ${ $msg->can('to_string_' . ($self->{'_big_endian'} ? 'be' : 'le'))->($msg) } );

    return $self->{'_io'}->flush_write_queue();
}

1;
