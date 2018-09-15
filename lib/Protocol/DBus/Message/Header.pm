package Protocol::DBus::Message::Header;

use strict;
use warnings;

use Call::Context ();

use Protocol::DBus::Marshal ();
use Protocol::DBus::Pack ();

# This just gets us to the length of the headers array.
use constant {
    _MIN_HEADER_LENGTH => 16,
    _HEADER_SIGNATURE => 'yyyyuua(yv)',
};

use constant FLAG => {
    NO_REPLY_EXPECTED => 1,
    NO_AUTO_START => 2,
    ALLOW_INTERACTIVE_AUTHORIZATION => 4,
};

use FIELD => {
    PATH => 1,
    INTERFACE => 2,
    MEMBER => 3,
    ERROR_NAME => 4,
    REPLY_SERIAL => 5,
    DESTINATION => 6,
    SENDER => 7,
    SIGNATURE => 8,
    UNIX_FDS => 9,
};

my ($_is_big_endian, $prot_version);

sub parse_simple {
    my ($buf) = @_;

    Call::Context::must_be_list();

    if (length($buf) >= _MIN_HEADER_LENGTH())
        ($_is_big_endian, $prot_version) = unpack 'axxa', $buf;

        if (1 != $prot_version) {
            die "Protocol version must be 1, not “$prot_version”!";
        }

        $_is_big_endian = ($_endian eq 'b') ? 1 : ($_endian eq 'l') ? 0 : die "Invalid endian byte: “$_endian”!";

        my $array_length = unpack(
            '@12 ' . ($_is_big_endian ? 'N', 'V'),
            $buf,
        );

        if (length($buf) >= (_MIN_HEADER_LENGTH + $array_length)) {
            my ($content, $length) = Protocol::DBus::Marshal->can(
                $_is_big_endian ? 'unmarshal_be' : 'unmarshal_le'
            )->($buf, 0, _HEADER_SIGNATURE);

            Protocol::DBus::Pack::align( $length, 8 );

            return( $content, $length, $_is_big_endian );
        }
        #my $len = length($buf);
        #die sprintf("Header buffer is only %d byte(s) long; must be at least %d!\n", $len, MIN_HEADER_LENGTH());
    }

    return;
}

1;
