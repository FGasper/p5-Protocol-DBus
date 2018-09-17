package Protocol::DBus::Message;

use strict;
use warnings;

use Protocol::DBus::Marshal ();
use Protocol::DBus::Message::Header ();

use constant _PROTOCOL_VERSION => 1;

sub parse {
    my ($class, $buf_sr) = @_;

    if ( my ($hdr, $hdr_len, $is_be) = Protocol::DBus::Message::Header::parse_simple($buf_sr) ) {

        if (length($$buf_sr) >= ($hdr_len + $hdr->[4])) {
            my $body_sig;

            for my $hfield ( @{ $hdr->[6] } ) {
                next if $hfield->[0] != Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'};

                $body_sig = $hfield->[1];
                last;
            }

            if ($hdr->[4]) {
                die "No SIGNATURE header field!" if !defined $body_sig;
            }

            my $body_data;

            if ($body_sig) {
                ($body_data) = Protocol::DBus::Marshal->can( 'unmarshal_' . ($is_be ? 'be' : 'le') )->($buf_sr, $hdr_len, $body_sig);
            }

            my %self = ( _body_sig => $body_sig );
            @self{'_type', '_flags', 'body_length', '_serial', '_hfields', '_body'} = (@{$hdr}[1, 2, 4, 5, 6], $body_data);

            # Remove the unmarshaled bytes.
            substr( $$buf_sr, 0, $hdr_len + $hdr->[4], q<> );

            return bless \%self, $class;
        }
    }

    return undef;
}

use constant _REQUIRED => ('type', 'serial', 'hfields');

sub new {
    my ($class, %opts) = @_;

    my @missing = grep { !defined $opts{$_} } _REQUIRED();
    die "missing: @missing" if @missing;

    $opts{'type'} = Protocol::DBus::Message::Header::MESSAGE_TYPE()->{ $opts{'type'} } || die "Bad “type”: '$opts{'type'}'";

    my $flags = 0;
    if ($opts{'flags'}) {
        for my $f (@{ $opts{'flags'} }) {
            $flags |= Protocol::DBus::Message::Header::FLAG()->{$f} || die "Bad “flag”: $f";
        }
    }

    $opts{'flags'} = $flags;

    my @hfields;

    if ($opts{'hfields'}) {
        for my $hf ( @{ $opts{'hfields'} } ) {
            my @field = (
                Protocol::DBus::Message::Header::FIELD()->{$hf->[0]} || do {
                    die "Bad “hfields” name: $hf->[0]";
                },
                [
                    Protocol::DBus::Message::Header::FIELD_SIGNATURE()->{$hf->[0]},
                    $hf->[1],
                ],
            );

            if ($field[0] == Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'}) {
                $opts{'_body_sig'} = $hf->[1];
            }

            push @hfields, bless \@field, 'Protocol::DBus::Type::Struct';
        }
    }

    $opts{'hfields'} = bless \@hfields, 'Protocol::DBus::Type::Array';

    if ($opts{'body'}) {
        die "“body” requires a SIGNATURE header!" if !$opts{'_body_sig'};
    }
    else {
        $opts{'body'} = \q<>;
    }

    my %self = map { ( "_$_" => $opts{$_} ) } keys %opts;

    return bless \%self, $class;
}

#----------------------------------------------------------------------

sub body {
    return $_[0]->{'_body'};
}

sub hfields {
    return $_[0]->{'_hfields'};
}

sub type {
    return $_[0]->{'_type'};
}

sub type_is {
    my ($self, $name) = @_;

    return $_[0]->{'_type'} == (Protocol::DBus::Message::Header::MESSAGE_TYPE()->{$name} || do {
        die "Invalid type name: $name";
    });
}

sub flags {
    return $_[0]->{'_flags'};
}

sub flags_have {
    my ($self, @names) = @_;

    die "Need flag names!" if !@names;

    for my $name (@names) {
        return 0 if !($_[0]->{'_flags'} & (Protocol::DBus::Message::Header::FLAG()->{$name} || do {
        die "Invalid flag name: “$name”";
        }));
    }

    return 1;
}

sub serial {
    return $_[0]->{'_serial'};
}

#----------------------------------------------------------------------

our $_use_be;

sub to_string_le {
    return _to_string(@_);
}

sub to_string_be {
    local $_use_be = 1;
    return _to_string(@_);
}

sub _to_string {
    my ($self) = @_;

    my $data = [
        ord('l'),
        $self->{'_type'},
        $self->{'_flags'},
        _PROTOCOL_VERSION(),
        length( ${ $self->{'_body'} } ),
        $self->{'_serial'},
        $self->{'_hfields'},
    ];

    my $buf_sr = Protocol::DBus::Marshal->can( $_use_be ? 'marshal_be' : 'marshal_le' )->(
        Protocol::DBus::Message::Header::SIGNATURE(),
        $data,
    );

    Protocol::DBus::Pack::align_str($$buf_sr, 8);

    if ($self->{'_body_sig'}) {
        ${ $buf_sr } .= ${ Protocol::DBus::Marshal->can( $_use_be ? 'marshal_be' : 'marshal_le' )->(
            $self->{'_body_sig'},
            $self->{'_body'},
        ) };
    }

    return $buf_sr;
}

1;
