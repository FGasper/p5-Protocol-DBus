package Protocol::DBus::Message;

use strict;
use warnings;

use Protocol::DBus::Marshal ();
use Protocol::DBus::Message::Header ();

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

use constant _REQUIRED = ('type', 'serial', 'hfields');

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

    #$opts{'type'} =  $opts{'type'} } or die "Bad 'type': '$opts{'type'}'";
1;
