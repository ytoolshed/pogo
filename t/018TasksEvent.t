
use warnings;
use strict;
use Test::More;
use Log::Log4perl qw(:easy);

my $nof_tests = 5;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

plan tests => $nof_tests;

use Pogo::Scheduler::Task;
use Pogo::Scheduler::Slot;

my $slot = Pogo::Scheduler::Slot->new();

my @tasks = ();

my $cv = AnyEvent->condvar();

$slot->reg_cb( "slot_done", sub {
    my( $c, $s ) = @_;
    ok 1, "received slot_done #1";
    $cv->send();
} );

for( 1..4 ) {
    my $task = Pogo::Scheduler::Task->new();
    push @tasks, $task;
    $slot->task_add( $task );
}

$slot->reg_cb( "task_run", sub {
    my( $c, $t ) = @_;

    DEBUG "Running task $t";
    ok 1, "task run $t";

    $slot->task_mark_done( $t );
    $slot->task_next();
} );

$slot->task_next();

$cv->recv();
