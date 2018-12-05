package Protocol::DBus::Path;

use strict;
use warnings;

use Protocol::DBus::Address ();

use constant _DEFAULT_SYSTEM_MESSAGE_BUS => 'unix:path=/var/run/dbus/system_bus_socket';

# NB: If this returns “autolaunch:”, then the system should use
# platform-specific methods of locating a running D-Bus session server,
# or starting one if a running instance cannot be found.
sub login_session_message_bus {
    return _parse_one_path($ENV{'DBUS_SESSION_BUS_ADDRESS'});
}

sub system_message_bus {
    return _parse_one_path( $ENV{'DBUS_SYSTEM_BUS_ADDRESS'} || _DEFAULT_SYSTEM_MESSAGE_BUS() );
}

sub _parse_one_path {
    my @unix = grep { $_->{'transport'} eq 'unix' } Protocol::DBus::Address::parse( $_[0] );

    # TODO: Typed exception.
    die "No “unix” paths ($_[0])!" if !@unix;

    return $unix[0]{'path'};
}

1;
