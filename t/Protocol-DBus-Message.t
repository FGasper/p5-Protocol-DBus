#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::FailWarnings;

use Data::Dumper;

use_ok('Protocol::DBus::Message');

use Protocol::DBus::Marshal;

my @stringify_le = (
    {
        label => 'bare “Hello” message',
        in => {
            type => 'METHOD_CALL',
            serial => 1,
            hfields => [
                PATH => '/org/freedesktop/DBus',
                INTERFACE => 'org.freedesktop.DBus',
                MEMBER => 'Hello',
                DESTINATION => 'org.freedesktop.DBus',
            ],
        },
        out => "l\1\0\1\0\0\0\0\1\0\0\0m\0\0\0\1\1o\0\25\0\0\0/org/freedesktop/DBus\0\0\0\2\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\3\1s\0\5\0\0\0Hello\0\0\0\6\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0",
    },
    {
        label => '“GetAll” call',
        in => {
            type => 'METHOD_CALL',
            serial => 3,
            hfields => [
                PATH => '/org/freedesktop/DBus',
                INTERFACE => 'org.freedesktop.DBus.Properties',
                MEMBER => 'GetAll',
                DESTINATION => 'org.freedesktop.DBus',
                SIGNATURE => 's',
            ],
            body => \'org.freedesktop.DBus',
        },
        out => "l\1\0\1\31\0\0\0\3\0\0\0\177\0\0\0\1\1o\0\25\0\0\0/org/freedesktop/DBus\0\0\0\2\1s\0\37\0\0\0org.freedesktop.DBus.Properties\0\3\1s\0\6\0\0\0GetAll\0\0\6\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\10\1g\0\1s\0\0\24\0\0\0org.freedesktop.DBus\0",
    },
);
use Carp::Always;

for my $t (@stringify_le) {
    local $Protocol::DBus::Marshal::DICT_CANONICAL = 1;

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
                Isa('Protocol::DBus::Type::Dict'),
                noclass( {
                    Protocol::DBus::Message::Header::FIELD()->{'PATH'} => '/org/freedesktop/DBus',
                    Protocol::DBus::Message::Header::FIELD()->{'MEMBER'} => 'Hello',
                    Protocol::DBus::Message::Header::FIELD()->{'INTERFACE'} => 'org.freedesktop.DBus',
                    Protocol::DBus::Message::Header::FIELD()->{'DESTINATION'} => 'org.freedesktop.DBus',
                } ),
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
                Isa('Protocol::DBus::Type::Dict'),
                noclass( {
                    Protocol::DBus::Message::Header::FIELD()->{'DESTINATION'} => ':1.174',
                    Protocol::DBus::Message::Header::FIELD()->{'REPLY_SERIAL'} => 1,
                    Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'} => 's',
                    Protocol::DBus::Message::Header::FIELD()->{'SENDER'} => 'org.freedesktop.DBus',
                } ),
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
                Isa('Protocol::DBus::Type::Dict'),
                noclass( {
                    Protocol::DBus::Message::Header::FIELD()->{'PATH'} => '/org/freedesktop/DBus',
                    Protocol::DBus::Message::Header::FIELD()->{'INTERFACE'} => 'org.freedesktop.DBus',
                    Protocol::DBus::Message::Header::FIELD()->{'MEMBER'} => 'NameAcquired',
                    Protocol::DBus::Message::Header::FIELD()->{'DESTINATION'} => ':1.174',
                    Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'} => 's',
                    Protocol::DBus::Message::Header::FIELD()->{'SENDER'} => 'org.freedesktop.DBus',
                } ),
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
                Isa('Protocol::DBus::Type::Dict'),
                noclass( {
                    Protocol::DBus::Message::Header::FIELD()->{'PATH'} => '/org/freedesktop/NetworkManager',
                    Protocol::DBus::Message::Header::FIELD()->{'MEMBER'} => 'Introspect',
                    Protocol::DBus::Message::Header::FIELD()->{'INTERFACE'} => 'org.freedesktop.DBus.Introspectable',
                    Protocol::DBus::Message::Header::FIELD()->{'DESTINATION'} => 'org.freedesktop.NetworkManager',
                } ),
            ),
        ],
    },
    {
        label => '“GetAll” response',
        in => "l\2\1\1\251\0\0\0\3\0\0\0E\0\0\0\6\1s\0\6\0\0\0:1.179\0\0\5\1u\0\2\0\0\0\10\1g\0\5a{sv}\0\0\0\0\0\0\7\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\241\0\0\0\0\0\0\0\10\0\0\0Features\0\2as\0\0\0\0&\0\0\0\10\0\0\0AppArmor\0\0\0\0\21\0\0\0SystemdActivation\0\0\0\n\0\0\0Interfaces\0\2as\0\0I\0\0\0\37\0\0\0org.freedesktop.DBus.Monitoring\0 \0\0\0org.freedesktop.DBus.Debug.Stats\0",
        methods => [
            [ type_is => 'METHOD_RETURN' ] => 1,
            [ flags_have => 'NO_REPLY_EXPECTED' ] => 1,
            hfields => all(
                Isa('Protocol::DBus::Type::Dict'),
                noclass( {
                    Protocol::DBus::Message::Header::FIELD()->{'DESTINATION'} => ':1.179',
                    Protocol::DBus::Message::Header::FIELD()->{'REPLY_SERIAL'} => 2,
                    Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'} => 'a{sv}',
                    Protocol::DBus::Message::Header::FIELD()->{'SENDER'} => 'org.freedesktop.DBus',
                }),
            ),
            body => [
                all(
                    Isa('Protocol::DBus::Type::Dict'),
                    noclass( {
                        Features => all(
                            Isa('Protocol::DBus::Type::Array'),
                            noclass( [
                                'AppArmor',
                                'SystemdActivation',
                            ] ),
                        ),
                        Interfaces => all(
                            Isa('Protocol::DBus::Type::Array'),
                            noclass( [
                                'org.freedesktop.DBus.Monitoring',
                                'org.freedesktop.DBus.Debug.Stats',
                            ] ),
                        ),
                    } ),
                ),
            ],
        ],
    },
    {
        label => 'error',
        in => "l\3\1\1S\0\0\0\3\0\0\0u\0\0\0\6\1s\0\6\0\0\0:1.123\0\0\4\1s\0)\0\0\0org.freedesktop.DBus.Error.ServiceUnknown\0\0\0\0\0\0\0\5\1u\0\2\0\0\0\10\1g\0\1s\0\0\7\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0N\0\0\0The name org.freedesktop.NetworkManager was not provided by any .service files\0",
        methods => [
            [ type_is => 'ERROR' ] => 1,
            [ flags_have => 'NO_REPLY_EXPECTED' ] => 1,
            hfields => all(
                Isa('Protocol::DBus::Type::Dict'),
                noclass( {
                    Protocol::DBus::Message::Header::FIELD()->{'DESTINATION'} => ':1.123',
                    Protocol::DBus::Message::Header::FIELD()->{'ERROR_NAME'} => 'org.freedesktop.DBus.Error.ServiceUnknown',
                    Protocol::DBus::Message::Header::FIELD()->{'REPLY_SERIAL'} => 2,
                    Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'} => 's',
                    Protocol::DBus::Message::Header::FIELD()->{'SENDER'} => 'org.freedesktop.DBus',
                } ),
            ),
            body => [
                'The name org.freedesktop.NetworkManager was not provided by any .service files',
            ],
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
