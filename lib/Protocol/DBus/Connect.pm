package Protocol::DBus::Connect;

use strict;
use warnings;

use Socket;

sub create_socket {
    my ($addr_obj) = @_;

    if ($addr_obj->transport() eq 'unix') {
        my $path = $addr_obj->attribute('path') or do {
            die( "No “path”: " . $addr_obj->to_string() );
        };

        socket my $s, Socket::AF_UNIX(), Socket::SOCK_STREAM(), 0 or do {
            die "socket(AF_UNIX, SOCK_STREAM): $!";
        };

        connect $s, Socket::pack_sockaddr_un($path) or do {
            die "connect($path): $!";
        };

        return $s;
    }

    # TODO: Handle TCP addresses.

    die( "Unrecognized path: " . $addr_obj->to_string() );
}

1;
