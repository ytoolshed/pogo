
use warnings;
use strict;
use Test::More;
use Log::Log4perl qw(:easy);

my $nof_tests = 6;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

plan tests => $nof_tests;

use Pogo::Scheduler::Thread;
use Pogo::Scheduler::Task;
use Pogo::Scheduler::Slot;

my $thread = Pogo::Scheduler::Thread->new();
my $slot = Pogo::Scheduler::Slot->new();

$thread->slot_add( $slot );

my @tasks = ();

my $cv = AnyEvent->condvar();

$slot->reg_cb( "slot_done", sub {
    my( $c, $s ) = @_;
    ok 1, "received slot_done #1";
} );

$thread->reg_cb( "thread_done", sub {
    my( $c, $s ) = @_;
    ok 1, "received thread_done #2";
    $cv->send();
} );

for( 1..4 ) {
    my $task = Pogo::Scheduler::Task->new();
    push @tasks, $task;
    DEBUG "Adding task $task";
    $slot->task_add( $task );
}

$slot->reg_cb( "task_run", sub {
    my( $c, $t ) = @_;

    DEBUG "Test suite 'running' task $t";
    ok 1, "task run $t";

    $thread->task_mark_done( $t );
} );

$thread->start();

$cv->recv();
