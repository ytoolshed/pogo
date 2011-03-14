
package PogoTesterProc;
use Log::Log4perl qw(:easy);

use Proc::Simple;

sub proc_starter {
    my( $name, $cmd ) = @_;

    my $proc = Proc::Simple->new();

    return sub {
        use vars qw($OLDOUT $OLDERR);

        open OLDOUT, ">&STDOUT";
        open OLDERR, ">&STDERR";

        open STDOUT, ">/tmp/$name.stdout.log";
        open STDERR, ">/tmp/$name.stderr.log";

        $proc->kill_on_destroy( 1 );
        DEBUG "Starting $cmd";
        $proc->start( $cmd );

        close(STDOUT);
        open(STDOUT, ">&OLDOUT");

        close(STDERR);
        open(STDERR, ">&OLDERR");

        return $proc;
    };
}

1;
