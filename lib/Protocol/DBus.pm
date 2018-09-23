package Protocol::DBus;

our $VERSION = 0.01;

=head1 NAME

Protocol::DBus

=head1 SYNOPSIS

    my $dbus = Protcol::DBus::Client->new(
        bus => 'login_session',
    );

    # By default we use blocking I/O, but non-blocking can be used, thus:
    $dbus->blocking(0);
    $dbus->fileno();

    $dbus->send_call(
        method => 'org.freedesktop.DBus.Properties.GetAll',
        signature => 's',
        path => '/org/freedesktop/DBus',
        destination => 'org.freedesktop.DBus',
        body => 'org.freedesktop.DBus',
        callback => sub { my ($msg) = @_ },
    );

    my $msg = $dbus->receive();

=head1 DESCRIPTION

This is an original, pure-Perl implementation of L<the D-Bus protocol|https://dbus.freedesktop.org/doc/dbus-specification.html>.

=head1 MAPPING

The following conventions are observed:


=head2 D-Bus -> Perl

=over

=item 

=cut
