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

            my $body_sig = $hdr->[6]{ Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'} };

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

    my %hfields;

    if ($opts{'hfields'}) {
        my $field_num;

        my $fi = 0;
        while ( $fi < @{ $opts{'hfields'} } ) {
            my ($name, $value) = @{ $opts{'hfields'} }[ $fi, 1 + $fi ];
            $fi += 2;

            $field_num = Protocol::DBus::Message::Header::FIELD()->{$name} || do {
                die "Bad “hfields” name: “$name”";
            };

            $hfields{ $field_num } = [
                Protocol::DBus::Message::Header::FIELD_SIGNATURE()->{$name},
                $value,
            ];

            if ($field_num == Protocol::DBus::Message::Header::FIELD()->{'SIGNATURE'}) {
                $opts{'body_sig'} = $value;
            }
        }
    }

    $opts{'hfields'} = bless \%hfields, 'Protocol::DBus::Type::Dict';

    if ($opts{'body'}) {
        die "“body” requires a SIGNATURE header!" if !$opts{'body_sig'};
    }
    elsif ($opts{'body_sig'}) {
        die "SIGNATURE header given without “body”!";
    }
    else {
        $opts{'body'} = \q<>;
    }

    my %self = map { ( "_$_" => $opts{$_} ) } keys %opts;

    return bless \%self, $class;
}

#----------------------------------------------------------------------

sub get_header {
    if ($_[1] =~ tr<0-9><>c) {
        return $_[0]->{'hfields'}{ Protocol::DBus::Message::Header::FIELD()->{$_[1]} || die("Bad header: “$_[1]”") };
    }

    return $_[0]->{'hfields'}{$_[1]};
}

sub get_body {
    return $_[0]->{'_body'};
}

sub get_type {
    return $_[0]->{'_type'};
}

sub type_is {
    my ($self, $name) = @_;

    return $_[0]->{'_type'} == (Protocol::DBus::Message::Header::MESSAGE_TYPE()->{$name} || do {
        die "Invalid type name: $name";
    });
}

sub get_flags {
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

#----------------------------------------------------------------------

sub _to_string {
    my ($self) = @_;

    my $body_m_sr;

    if ($self->{'_body_sig'}) {
        $body_m_sr = Protocol::DBus::Marshal->can( $_use_be ? 'marshal_be' : 'marshal_le' )->(
            $self->{'_body_sig'},
            ${ $self->{'_body'} },
        );
    }

    my $data = [
        ord('l'),
        $self->{'_type'},
        $self->{'_flags'},
        _PROTOCOL_VERSION(),
        $body_m_sr ? length( $$body_m_sr ) : 0,
        $self->{'_serial'},
        $self->{'_hfields'},
    ];

    my $buf_sr = Protocol::DBus::Marshal->can( $_use_be ? 'marshal_be' : 'marshal_le' )->(
        Protocol::DBus::Message::Header::SIGNATURE(),
        $data,
    );

    Protocol::DBus::Pack::align_str($$buf_sr, 8);

    $$buf_sr .= $$body_m_sr if $body_m_sr;

    return $buf_sr;
}

1;
