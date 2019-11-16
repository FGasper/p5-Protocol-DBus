package Protocol::DBus::Client::AsyncMessenger;

use strict;
use warnings;

sub new {
    my ($class, $dbus, $post_send_cr) = @_;

    return bless [$dbus, $post_send_cr], $class;
}

sub send_call {
    return _wrap_send( @_ );
}

sub send_return {
    return _wrap_send( @_ );
}

sub send_error {
    return _wrap_send( @_ );
}

sub send_signal {
    return _wrap_send( @_ );
}

sub _wrap_send {
    my ($self) = @_;

    my $fn = (caller 1)[3];
    substr( $fn, 0, 1 + rindex($fn, ':') ) = q<>;

    my $ret = $self->[0]->$fn( @_[1 .. $#_] );

    $self->[1]->();

    return $ret;
}

1;
