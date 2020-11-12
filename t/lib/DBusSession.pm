package DBusSession;

use strict;
use warnings;

use File::Which;
use File::Temp;

use Test::More;

sub get_bin {
    return File::Which::which('dbus-run-session');
}

sub get_bin_or_skip {
    my $bin = get_bin();

    skip 'No dbus-run-session', 1 if !$bin;

    return $bin;
}

sub new {
    my $class = shift;

    my $dbus_run_session_bin = get_bin() or die "no dbus-run-session!";

    my $dir = File::Temp::tempdir();

    my $pid = open my $rfh, '-|', "$dbus_run_session_bin -- $^X -MTime::HiRes -e'\$| = 1; print \$ENV{DBUS_SESSION_BUS_ADDRESS} . \$/; Time::HiRes::sleep(0.1) while !-e qq<$dir/done>'";

    diag "reading bus address from child …";

    my $address = readline($rfh);
    chomp $address if $address;

    if ($address) {
        diag "bus address: $address";
    }
    else {
        diag "Received no bus address from child!";
    }

    my $existing = exists $ENV{'DBUS_SESSION_BUS_ADDRESS'};

    my %self = (
        dir => $dir,
        existing => $existing && [$ENV{'DBUS_SESSION_BUS_ADDRESS'}],
        rfh => $rfh,
        pid => $pid,
    );

    $ENV{'DBUS_SESSION_BUS_ADDRESS'} = $address;

    return bless \%self, $class;
}

sub DESTROY {
    my ($self) = @_;

    open my $wfh, '>', "$self->{'dir'}/done";
    close $wfh;

    close $self->{'rfh'};
    waitpid $self->{'pid'}, 0;

    if ($self->{'existing'}) {
        $ENV{'DBUS_SESSION_BUS_ADDRESS'} = $self->{'existing'}[0];
    }
    else {
        delete $ENV{'DBUS_SESSION_BUS_ADDRESS'};
    }

    return;
}

1;
