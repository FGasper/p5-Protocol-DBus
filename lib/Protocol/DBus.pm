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

    my $msg = $dbus->get_message();

For non-blocking I/O:

    $dbus->blocking(0);

    my $fileno = $dbus->fileno();

    # You can use whatever polling method you prefer;
    # the following is just for demonstration:
    vec( my $mask, $fileno, 1 ) = 1;

    while (!$dbus->do_authn()) {
        if ($dbus->authn_pending_send()) {
            select( undef, my $wout = $mask, undef, undef );
        }
        else {
            select( my $rout = $mask, undef, undef, undef );
        }
    }

    $dbus->send_call( .. );     # same parameters as above

    while (1) {
        my $wout = $dbus->pending_send() || q<>;
        $wout &&= $mask;

        select( my $rout = $mask, $wout, undef, undef );

        if ($wout =~ tr<\0><>c) {
            $dbus->flush_write_queue();
        }

        if ($rout =~ tr<\0><>c) {

            # It’s critical to get_message() until undef is returned.
            1 while $dbus->get_message();
        }
    }

=head1 DESCRIPTION

This is an original, pure-Perl implementation of L<the D-Bus protocol|https://dbus.freedesktop.org/doc/dbus-specification.html>.

=cut