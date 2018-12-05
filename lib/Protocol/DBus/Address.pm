package Protocol::DBus::Address;

use strict;
use warnings;

use Call::Context;

sub parse {
    Call::Context::must_be_list();

    return map {
        my $xport = substr( $_, 0, 1 + index($_, ':'), q<> );
        chop $xport;

        my %kvs = (
            transport => $xport,
            map { split m<=>, $_ } (split m<,>, $_),
        );

        s<%(..)><chr hex $1>g for values %kvs;

        \%kvs;
    } ( split m<;>, $_[0] );
}

1;
