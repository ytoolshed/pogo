
use warnings;
use strict;
use AnyEvent;
use Pogo::Plugin;
use Test::More;
use Log::Log4perl qw(:easy);

plan tests => 1;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Pogo::Scheduler;

my $s = Pogo::Scheduler->new();

my $task1 = "task1";

$s->reg_cb( "task_run", sub {
    my( $c, $task ) = @_;

    is $task, $task1, "task scheduled #1";
} );

$s->task_add( $task1 );
