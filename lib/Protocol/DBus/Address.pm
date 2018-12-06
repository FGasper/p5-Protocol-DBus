package Protocol::DBus::Address;

use strict;
use warnings;

use Call::Context;

# Not a very choosy parser, and it doesn’t try to validate anything.
sub parse {
    Call::Context::must_be_list();

    return map {
        my $xport = substr( $_, 0, 1 + index($_, ':'), q<> );
        chop $xport;

        my %kvs = (
            transport => $xport,
            map { split m<=>, $_ } (split m<,>, $_),
        );

        s<%(..)><chr hex $1>ge for values %kvs;

        \%kvs;
    } ( split m<;>, $_[0] );
}

1;
