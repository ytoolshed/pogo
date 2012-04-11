
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

for( 1..4 ) {
    my $task = Pogo::Scheduler::Task->new();
    push @tasks, $task;
    $slot->task_add( $task );
}

while( my $task = $slot->task_next() ) {
    my $exp = shift @tasks;

    is "$task", "$exp", "next task";

    $slot->task_mark_done( $task );
}

is $slot->tasks_active(), 0, "no more active tasks";
