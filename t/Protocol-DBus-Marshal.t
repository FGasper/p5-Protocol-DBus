#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::FailWarnings;

use Data::Dumper;

use_ok('Protocol::DBus::Marshal');

#----------------------------------------------------------------------

my @too_short = (
    [ "\x02\0\0\0hi\0" . "\0" . "\x04\0". "\x02", 0, '(s(qq))'],
);

for my $t (@too_short) {
    my $str = _str_for_buf_offset_sig(@$t);
    ok(
        !Protocol::DBus::Marshal::buffer_length_satisfies_signature_le(@$t),
        "too short: $str",
    );
}

my @positive_le_tests = (
    {
        in => ["\x0a\0\0\0", 0, 'u'],
        out => [ [10], 4 ],
    },

    {
        in => ["\0\0\0\0\x0a\0\0\0", 1, 'u'],
        out => [ [10], 7 ],
    },

    {
        in => ["\x02\0\0\0hi\0" . "\0" . "\x04\0". "\x02\0", 0, '(s(qq))'],
        out => [
            [ all(
                noclass( [ 'hi', all(
                    noclass( [ 4, 2 ] ),
                    Isa('Protocol::DBus::Type::Struct'),
                ) ] ),
                Isa('Protocol::DBus::Type::Struct'),
            ) ],
            12,
        ],
    },

    {
        in => ["\0\0\0\0" . "\x08\0\0\0" . "\x0a\0\0\0" . "\0\1\0\0", 2, 'au'],
        out => [
            [ all(
                noclass([ 10, 256 ]),
                Isa('Protocol::DBus::Type::Array'),
            ) ],
            14,
        ],
    },

    {
        in => ["\0\0\0\0" . "\x10\0\0\0" . "\x0a\0\0\0" . "\0\1\0\0" . "\x02\0\0\0" . "\x10\0\0\0", 2, 'a{uu}'],
        out => [
            [ all(
                Isa('Protocol::DBus::Type::Dict'),
                noclass( { 10 => 256, 2 => 16 } ),
            ) ],
            22,
        ],
    },
    {
        in => ["\0\0\0\0\237\0\0\0\1\1o\0.\0\0\0/org/freedesktop/systemd1/unit/spamd_2eservice\0\0\3\1s\0\6\0\0\0GetAll\0\0\2\1s\0\37\0\0\0org.freedesktop.DBus.Properties\0\6\1s\0\30\0\0\0org.freedesktop.systemd1\0\0\0\0\0\0\0\0\10\1g\0\1s\0\0", 1, 'a(yv)'],
        out => [
            [ all(
                Isa('Protocol::DBus::Type::Array'),
                noclass( [
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [
                            1,
                            '/org/freedesktop/systemd1/unit/spamd_2eservice',
                        ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [
                            3,
                            'GetAll',
                        ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [
                            2,
                            'org.freedesktop.DBus.Properties',
                        ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [
                            6,
                            'org.freedesktop.systemd1',
                        ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [
                            8,
                            's',
                        ] ),
                    ),
                ] ),
            ) ],
            166,
        ],
    },
    {
        in => ["l\1\0\1\5\0\0\0\1\0\0\0\237\0\0\0\1\1o\0.\0\0\0/org/freedesktop/systemd1/unit/spamd_2eservice\0\0\3\1s\0\6\0\0\0GetAll\0\0\2\1s\0\37\0\0\0org.freedesktop.DBus.Properties\0\6\1s\0\30\0\0\0org.freedesktop.systemd1\0\0\0\0\0\0\0\0\10\1g\0\1s\0\0", 0, 'yyyyuua(yv)'],
        out => [
            [
                108,
                1,
                0,
                1,
                5,
                1,
                all(
                    Isa('Protocol::DBus::Type::Array'),
                    noclass( [
                        all(
                            Isa('Protocol::DBus::Type::Struct'),
                            noclass( [
                                1,
                                '/org/freedesktop/systemd1/unit/spamd_2eservice',
                            ] ),
                        ),
                        all(
                            Isa('Protocol::DBus::Type::Struct'),
                            noclass( [
                                3,
                                'GetAll',
                            ] ),
                        ),
                        all(
                            Isa('Protocol::DBus::Type::Struct'),
                            noclass( [
                                2,
                                'org.freedesktop.DBus.Properties',
                            ] ),
                        ),
                        all(
                            Isa('Protocol::DBus::Type::Struct'),
                            noclass( [
                                6,
                                'org.freedesktop.systemd1',
                            ] ),
                        ),
                        all(
                            Isa('Protocol::DBus::Type::Struct'),
                            noclass( [
                                8,
                                's',
                            ] ),
                        ),
                    ] ),
                ),
            ],
            175,
        ],
    },
);

for my $t (@positive_le_tests) {
    my ($buf, $buf_offset, $sig) = @{ $t->{'in'} };

    my $str = _str_for_buf_offset_sig( $buf, $buf_offset, $sig);

    #$str .= "] → [" . join(', ', map { Dumper($_) } @{ $t->{'out'} } ) . ']';

    my ($data, $offset_delta) = Protocol::DBus::Marshal::unmarshal_le(@{ $t->{'in'} });

    cmp_deeply(
        [$data, $offset_delta],
        $t->{'out'},
        "unmarshal_le: $str",
    ) or diag explain [$data, $offset_delta];

    ok(
        Protocol::DBus::Marshal::buffer_length_satisfies_signature_le(@{ $t->{'in'} }),
        '… and length satisfies',
    );

    ok(
        !Protocol::DBus::Marshal::buffer_length_satisfies_signature_le(substr($buf, 0, -5), $buf_offset, $sig),
        '… and buffer minus 5 bytes doesn’t satisfy length',
    );
}

sub _str_for_buf_offset_sig {
    my ($buf, $buf_offset, $sig) = @_;

    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Useqq = 1;

    return '[' . join(', ', Dumper($buf), $buf_offset, $sig) . ']';
}

#----------------------------------------------------------------------

done_testing();
