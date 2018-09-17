#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::FailWarnings;

use Data::Dumper;

use_ok('Protocol::DBus::Message');

my @stringify_le = (
    {
        label => 'bare “Hello” message',
        in => {
            type => 'METHOD_CALL',
            serial => 1,
            hfields => [
                [ PATH => '/org/freedesktop/DBus' ],
                [ MEMBER => 'Hello' ],
                [ INTERFACE => 'org.freedesktop.DBus' ],
                [ DESTINATION => 'org.freedesktop.DBus' ],
            ],
        },
        out => "l\1\0\1\0\0\0\0\1\0\0\0m\0\0\0\1\1o\0\25\0\0\0/org/freedesktop/DBus\0\0\0\3\1s\0\5\0\0\0Hello\0\0\0\2\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\6\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0",
    },
);

for my $t (@stringify_le) {
    my $msg = Protocol::DBus::Message->new( %{ $t->{'in'} } );

    my $out_sr = $msg->to_string_le();

    is_deeply(
        $out_sr,
        \$t->{'out'},
        $t->{'label'},
    ) or diag _terse_dump( [ $out_sr, \$t->{'out'} ] );
}

sub _terse_dump {
    my ($thing) = @_;

    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Useqq = 1;

    return Dumper($thing);
}

#----------------------------------------------------------------------

my @parse_le = (
    {
        label => 'bare “Hello” message',
        in => "l\1\0\1\0\0\0\0\1\0\0\0m\0\0\0\1\1o\0\25\0\0\0/org/freedesktop/DBus\0\0\0\3\1s\0\5\0\0\0Hello\0\0\0\2\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\6\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0",
        methods => [
            type => Protocol::DBus::Message::Header::MESSAGE_TYPE()->{'METHOD_CALL'},
            flags => 0,
            serial => 1,
            hfields => all(
                Isa('Protocol::DBus::Type::Array'),
                noclass( [
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'PATH'} => '/org/freedesktop/DBus' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'MEMBER'} => 'Hello' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'INTERFACE'} => 'org.freedesktop.DBus' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'DESTINATION'} => 'org.freedesktop.DBus'] ),
                    ),
                ] ),
            ),
        ],
    },
    {
        label => '“Hello” response',
        in => "l\2\1\1\x0b\0\0\0\1\0\0\0=\0\0\0\6\1s\0\6\0\0\0:1.174\0\0\5\1u\0\1\0\0\0\10\1g\0\1s\0\0\7\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\6\0\0\0:1.174\0",
        methods => [
            type => Protocol::DBus::Message::Header::MESSAGE_TYPE()->{'METHOD_RETURN'},
            flags => 1,
            serial => 1,
            hfields => all(
                Isa('Protocol::DBus::Type::Array'),
                noclass( [
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'DESTINATION'} => ':1.174' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'REPLY_SERIAL'} => 1 ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'} => 's' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'SENDER'} => 'org.freedesktop.DBus'] ),
                    ),
                ] ),
            ),
            body => [ ':1.174' ],
        ]
    },
    {
        label => 'signal',
        in => "l\4\1\1\x0b\0\0\0\2\0\0\0\215\0\0\0\1\1o\0\25\0\0\0/org/freedesktop/DBus\0\0\0\2\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\3\1s\0\f\0\0\0NameAcquired\0\0\0\0\6\1s\0\6\0\0\0:1.174\0\0\10\1g\0\1s\0\0\7\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\6\0\0\0:1.174\0",
        methods => [
            type => Protocol::DBus::Message::Header::MESSAGE_TYPE()->{'SIGNAL'},
            flags => 1,
            serial => 2,
            hfields => all(
                Isa('Protocol::DBus::Type::Array'),
                noclass( [
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'PATH'} => '/org/freedesktop/DBus' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'INTERFACE'} => 'org.freedesktop.DBus' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'MEMBER'} => 'NameAcquired' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'DESTINATION'} => ':1.174' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'} => 's' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'SENDER'} => 'org.freedesktop.DBus'] ),
                    ),
                ] ),
            ),
            body => [ ':1.174' ],
        ],
    },
    {
        label => 'Introspect',
        in => "l\1\0\1\0\0\0\0\2\0\0\0\227\0\0\0\1\1o\0\37\0\0\0/org/freedesktop/NetworkManager\0\3\1s\0\n\0\0\0Introspect\0\0\0\0\0\0\2\1s\0#\0\0\0org.freedesktop.DBus.Introspectable\0\0\0\0\0\6\1s\0\36\0\0\0org.freedesktop.NetworkManager\0\0",
        methods => [
            type => Protocol::DBus::Message::Header::MESSAGE_TYPE()->{'METHOD_CALL'},
            flags => 0,
            serial => 2,
            hfields => all(
                Isa('Protocol::DBus::Type::Array'),
                noclass( [
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'PATH'} => '/org/freedesktop/NetworkManager' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'MEMBER'} => 'Introspect' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'INTERFACE'} => 'org.freedesktop.DBus.Introspectable' ] ),
                    ),
                    all(
                        Isa('Protocol::DBus::Type::Struct'),
                        noclass( [ Protocol::DBus::Message::Header::FIELD()->{'DESTINATION'} => 'org.freedesktop.NetworkManager' ] ),
                    ),
                ] ),
            ),
        ],
    },
);

for my $t (@parse_le) {
    my $in_copy = $t->{'in'};

    my $msg = Protocol::DBus::Message->parse( \$in_copy );

    cmp_deeply(
        $msg,
        methods( @{ $t->{'methods'} } ),
        'parse: ' . $t->{'label'},
    ) or diag explain $msg;

    is(
        length($in_copy),
        $t->{'leftover'} || 0,
        '… and the buffer was trimmed appropriately',
    );
}

done_testing();
