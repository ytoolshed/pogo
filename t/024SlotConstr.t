
use warnings;
use strict;
use Test::More;
use Log::Log4perl qw(:easy);

my $nof_tests = 2;

plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Pogo::Scheduler::Slot;
use Pogo::Scheduler::Task;

my $slot = Pogo::Scheduler::Slot->new(
    constraint_cfg => {
        max_parallel => 2
    }
);

$slot->task_add( Pogo::Scheduler::Task->new() );
$slot->task_add( Pogo::Scheduler::Task->new() );

$slot->reg_cb( "task_run", sub {
    my( $c, $task ) = @_;

    ok 1, "Running task $task";

      # report back that task is done
    $slot->event( "task_mark_done", $task );
} );

my $cv = AnyEvent->condvar();

$slot->reg_cb( "slot_done", sub {
  my( $c ) = @_;

  $cv->send();
} );

  # start as many tasks as possible in parallel
$slot->start();

$cv->recv();
