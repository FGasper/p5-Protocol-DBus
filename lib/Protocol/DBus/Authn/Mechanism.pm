package Protocol::DBus::Authn::Mechanism;

use strict;
use warnings;

use constant INITIAL_RESPONSE => ();
use constant AFTER_AUTH => ();

sub new {
    my $self = bless {}, shift;

    $self->{'_skip_unix_fd'} = 1 if !Socket::MsgHdr->can('new') || !Socket->can('SCM_RIGHTS');

    return $self;
}

sub label {
    my $class = ref($_[0]) || $_[0];

    return substr( $class, 1 + rindex($class, ':') );
}

1;
