package Protocol::DBus::Message;

use strict;
use warnings;

use Protocol::DBus::Marshal ();
use Protocol::DBus::Message::Header ();

use constant _PROTOCOL_VERSION => 1;

sub parse {
    my ($class, $buf) = @_;

    if ( my ($hdr, $hdr_len, $is_be) = Protocol::DBus::Message::Header::parse_simple($buf) ) {

        if (length($buf) >= ($hdr_len + $hdr->[4])) {
            my $body_sig;

            for my $hfield ( @{ $hdr->[6] } ) {
                next if $hfield->[0] != Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'};

                $body_sig = $hfield->[1];
                last;
            }

            die "No SIGNATURE header field!" if !defined $body_sig;

            my ($body_data) = Protocol::DBus::Marshal->can( 'unmarshal_' . ($is_be ? 'be' : 'le') )->($buf, $hdr_len, $body_sig);

            my %self;
            @self{'type', 'flags', 'body_length', 'serial', 'hfields', 'body'} = (@{$hdr}[1, 2, 4, 5, 6], $body_data);

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

            if ($hf->[0] == Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'}) {
                $opts{'_body_sig'} = $hf->[1];
            }

            push @hfields, \@field;
        }
    }

    $opts{'hfields'} = \@hfields;

    if (defined $opts{'body'} && length $opts{'body'}) {
        if (!$opts{'_body_sig'}) {
            die "“body” requires a SIGNATURE header!";
        }
    }
    else {
        $opts{'body'} = q<>;
    }

    my %self = map { "$_" => $opts{$_} } keys %opts;

    return bless \%self, $class;
}

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
        length( $self->{'_body'} ),
        $self->{'_serial'},
        $self->{'_hfields'},
    ];

    my $hdr_buf = Protocol::DBus::Marshal->( $_is_be ? 'marshal_be' : 'marshal_le' )->(
        Protocol::DBus::Message::Header::SIGNATURE(),
        $data,
    );

    Protocol::DBus::Pack::align_str($hdr_buf, 8);

    if ($self->{'_body_sig'}) {
        $hdr_buf .= Protocol::DBus::Marshal->( $_is_be ? 'marshal_be' : 'marshal_le' )->(
            $self->{'_body_sig'},
            $self->{'_body'},
        );
    );

    return \$hdr_buf;
}

1;
