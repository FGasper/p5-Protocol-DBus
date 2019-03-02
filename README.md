# NAME

Protocol::DBus - D-Bus in pure Perl

# SYNOPSIS

    my $dbus = Protcol::DBus::Client::system();

For blocking I/O:

    # Authentication and “Hello” call/response:
    $dbus->initialize();

    $dbus->send_call(
        path => '/org/freedesktop/DBus',
        interface => 'org.freedesktop.DBus.Properties',
        member => 'GetAll',
        destination => 'org.freedesktop.DBus',
        signature => 's',
        body => [ 'org.freedesktop.DBus' ],
        on_return => sub { my ($msg) = @_ },
    );

    my $msg = $dbus->get_message();

For non-blocking I/O:

    $dbus->blocking(0);

    my $fileno = $dbus->fileno();

    # You can use whatever polling method you prefer;
    # the following is just for demonstration:
    vec( my $mask, $fileno, 1 ) = 1;

    while (!$dbus->initialize()) {
        if ($dbus->init_pending_send()) {
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

# DESCRIPTION

This is an original, pure-Perl implementation of client messaging logic for
[the D-Bus protocol](https://dbus.freedesktop.org/doc/dbus-specification.html).

This library doesn’t know about objects, services, or anything else besides
the actual messages. If you want to deal with D-Bus’s actual object
system—which you likely do if you’re building a real application—see
["SEE ALSO"](#see-also) below.

See [Protocol::DBus::Client](https://metacpan.org/pod/Protocol::DBus::Client) and the above sample for a starting point.

# EXAMPLES

See the distribution’s `examples/` directory.

# NOTES

- UNIX FD support requires that [Socket::MsgHdr](https://metacpan.org/pod/Socket::MsgHdr) be loaded at
authentication time.
- Certain OSes may require [Socket::MsgHdr](https://metacpan.org/pod/Socket::MsgHdr) to function.
(Linux, notably, does not.)
- EXTERNAL and DBUS\_COOKIE\_SHA1 authentication is supported.

# TODO

- Improve parsing of bus paths in environment variables.
- Add more tests.

# SEE ALSO

The most mature, stable D-Bus implementation in Perl is [Net::DBus](https://metacpan.org/pod/Net::DBus),
an XS binding to [libdbus](https://www.freedesktop.org/wiki/Software/dbus/),
the reference D-Bus implementation.

There is also [App::DBus](https://metacpan.org/pod/App::DBus), which builds upon the present module.
It’s pure Perl and takes a different approach to D-Bus’s object framework
than Net::DBus.
