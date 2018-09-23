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

sub get_message {
    my $msg = $_[0]->{'_parser'}->get_message();

    if (my $serial = $msg->get_header('REPLY_SERIAL')) {
        if (my $cb = delete $_[0]->{'_on_return'}{$serial}) {
            $cb->($msg);
        }
    }

    return $msg;
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

sub set_little_endian {
    my ($self) = @_;

    $self->{'_endian'} = 'le';

    return $self;
}

sub set_big_endian {
    my ($self) = @_;

    $self->{'_endian'} = 'be';

    return $self;
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

    $self->{'_io'}->write( ${ $msg->can("to_string_$self->{'_endian'}")->($msg) } );

    return $self->{'_io'}->flush_write_queue();
}

1;
