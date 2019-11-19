# NAME

Protocol::DBus - D-Bus in pure Perl

# SYNOPSIS

(NB: Examples below assume use of
[subroutine signatures](https://metacpan.org/pod/perlsub#Signatures).)

For blocking I/O:

    my $dbus = Protcol::DBus::Client::system();

    # Authentication and “Hello” call/response:
    $dbus->initialize();

    $dbus->send_call(
        path => '/org/freedesktop/DBus',
        interface => 'org.freedesktop.DBus.Properties',
        member => 'GetAll',
        destination => 'org.freedesktop.DBus',
        signature => 's',
        body => [ 'org.freedesktop.DBus' ],
    )->then( sub ($resp_msg) { .. } );

    my $msg = $dbus->get_message();

For non-blocking I/O, it is recommended to use either
[Protocol::DBus::Client::IOAsync](https://metacpan.org/pod/Protocol::DBus::Client::IOAsync) (for [IO::Async](https://metacpan.org/pod/IO::Async)) or
[Protocol::DBus::Client::AnyEvent](https://metacpan.org/pod/Protocol::DBus::Client::AnyEvent) (for [AnyEvent](https://metacpan.org/pod/AnyEvent)).

Example:

    my $loop = IO::Async::Loop->new();

    Protcol::DBus::Client::IOAsync::login_session($loop)->then(
        sub ($dbus) {
            $dbus->send_call( … );
        },
    )->finally( sub { $loop->stop() } );

    $loop->run();

See below for an example using a manually-written event loop.

# DESCRIPTION

This is an original, pure-Perl implementation of client messaging logic for
[the D-Bus protocol](https://dbus.freedesktop.org/doc/dbus-specification.html).

It’s not much more than an implementation of the wire protocol; it doesn’t
know about objects, services, or anything else besides the actual messages.
This is fine, of course, if all you want to do is, e.g., replace
an invocation of `gdbus` or `dbus-send` with pure Perl.

If you want an interface that mimics D-Bus’s actual object system,
you’ll need to implement it yourself or to look elsewhere.
(See ["SEE ALSO"](#see-also) below.)

# STATUS

This project is in BETA status. While the API should be pretty stable now,
breaking changes can still happen. If you use this module
in your project, you **MUST** check the changelog before deploying a new
version. Please file bug reports as appropriate.

# EXAMPLES

See [Protocol::DBus::Client](https://metacpan.org/pod/Protocol::DBus::Client) and the above samples for a starting point.

Also see the distribution’s `examples/` directory.

# NOTES

- UNIX FD support requires that [Socket::MsgHdr](https://metacpan.org/pod/Socket::MsgHdr) be loaded at
authentication time.
- Certain OSes may require [Socket::MsgHdr](https://metacpan.org/pod/Socket::MsgHdr) in order to authenticate
via a UNIX socket. (Linux, notably, does not.) It depends if your OS can
send local socket credentials without using `sendmsg(2)`.
- EXTERNAL and DBUS\_COOKIE\_SHA1 authentications are supported.

# TODO

- Improve parsing of bus paths in environment variables.
- Add more tests.

# SEE ALSO

The most mature, stable D-Bus implementation in Perl is [Net::DBus](https://metacpan.org/pod/Net::DBus),
an XS binding to [libdbus](https://www.freedesktop.org/wiki/Software/dbus/),
the reference D-Bus implementation.

# EXAMPLE USING MANUALLY-WRITTEN EVENT LOOP

    my $dbus = Protcol::DBus::Client::system();

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

Life is easier if you use someone else’s event loop. :)
