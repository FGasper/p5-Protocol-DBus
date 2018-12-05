package Protocol::DBus::Authn::Mechanism::DBUS_COOKIE_SHA1;

# https://dbus.freedesktop.org/doc/dbus-specification.html#auth-mechanisms-sha

use strict;
use warnings;

use parent qw( Protocol::DBus::Authn::Mechanism );

my $sha_module;

use constant must_send_initial => 0;

use constant KEYRINGS_DIR => '.dbus-keyrings';

sub new {
    my ($class) = @_;

    local $@;

    if ( eval { require Digest::SHA1; 1 } ) {
        $sha_module = 'Digest::SHA1';
    }
    elsif ( eval { require Digest::SHA; 1 } ) {
        $sha_module = 'Digest::SHA';
    }
    else {
        die "No SHA module available!";
    }

    return $class->SUPER::new( @_[ 1 .. $#_ ] );
}

sub INITIAL_RESPONSE {
    my ($self) = @_;

    return unpack( 'H*', ($self->_getpw())[0] );
}

sub AFTER_AUTH {
    my ($self) = @_;

    return (
        [ 1 => sub {
            _consume_data($self, @_);
        } ],
        [ 0 => \&_authn_respond_data ],
    );
}

sub _getpw {
    my ($self) = @_;

    $self->{'_pw'} ||= [ getpwuid $> ];

    return @{ $self->{'_pw'} };
}

sub _consume_data {
    my ($self, $authn, $line) = @_;

    if (0 != index($line, 'DATA ')) {
        die "Invalid line: [$line]";
    }

    substr( $line, 0, 5, q<> );

    my ($ck_ctx, $ck_id, $sr_challenge) = split m< >, pack( 'H*', $line );

    my $cookie = $self->_get_cookie($ck_ctx, $ck_id);

    my $cl_challenge = pack( 's8', map { rand 65536 } 1 .. 8 );

    my $str = join(
        ':',
        $sr_challenge,
        $cl_challenge,
        $cookie,
    );

    my $str_digest = $sha_module->can('sha1_hex')->($str);

    $authn->{'_sha1_response'} = unpack 'H*', "$cl_challenge $str_digest";

    return;
}

sub _authn_respond_data {
    return (
        'DATA',
        $_[0]->{'_sha1_response'} || do {
           die "No SHA1 DATA response set!";
        },
    );
}

sub _get_cookie {
    my ($self, $ck_ctx, $ck_id) = @_;

    my $path = File::Spec->catfile(
        ($self->_getpw())[7],
        KEYRINGS_DIR(),
        $ck_ctx,
    );

    open my $rfh, '<', $path or die "open(< $path): $!";

    while ( my $line = <$rfh> ) {
        chomp $line;

        next if 0 != index( $line, "$ck_id " );

        return substr( $line, 1 + index($line, q< >, 2 + length($ck_id)) );
    }

    die "Failed to find cookie “$ck_id” in “$path”!";
}

1;
