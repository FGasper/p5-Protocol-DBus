package Protocol::DBus;

our $VERSION = 0.01;

=head1 NAME

Protocol::DBus

=head1 SYNOPSIS

    my $dbus = Protcol::DBus::Client::system();

For blocking I/O:

    $dbus->do_authn();

    $dbus->send_call(
        method => 'org.freedesktop.DBus.Properties.GetAll',
        signature => 's',
        path => '/org/freedesktop/DBus',
        destination => 'org.freedesktop.DBus',
        body => 'org.freedesktop.DBus',
        callback => sub { my ($msg) = @_ },
    );

    my $msg = $dbus->receive();

For non-blocking I/O:

    $dbus->blocking(0);

    my $fileno = $dbus->fileno();

    # You can use whatever polling method you prefer;
    # the following is quick and easy:
    vec( my $mask, $fileno, 1 ) = 1;

    while (!$dbus->do_authn()) {
        if ($dbus->authn_pending_send()) {
            select( undef, my $wout = $mask, undef, undef );
        }
        else {
            select( my $rout = $mask, undef, undef, undef );
        }
    }

    while ( my $msg = $dbus->send_receive() ) { .. }

XXX TODO

=head1 DESCRIPTION

This is an original, pure-Perl implementation of L<the D-Bus protocol|https://dbus.freedesktop.org/doc/dbus-specification.html>.

Its features include:

=over

=item blocking or non-blocking I/O

=item 

=back

=head1 MAPPING

The following conventions are observed:


=head2 D-Bus -> Perl

=over

=item 

=cut
