
use warnings;
use strict;
use Test::More;
use Log::Log4perl qw(:easy);
use Pogo::Util::Bucketeer;

my $nof_tests = 6;

plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Pogo::Scheduler::Classic;
my $scheduler = Pogo::Scheduler::Classic->new();

my $cv = AnyEvent->condvar();

$scheduler->config_load( \ <<'EOT' );
tag:
  colo:
    north_america:
      - host1
      - host2
      - host3
    south_east_asia:
      - host4
      - host5
      - host6
sequence:
  - $colo.south_east_asia
  - $colo.north_america

constraint:
    $colo.north_america: 
       max_parallel: 3
EOT
 
my $bck = Pogo::Util::Bucketeer->new(
    buckets => [
  [ qw( host4 host5 host6 ) ],
  [ qw( host1 host2 host3 ) ],
] );

my @timers = ();

$scheduler->reg_cb( "task_run", sub {
    my( $c, $task ) = @_;

    my $host = $task->{ host };

    ok $bck->item( $host ), "host $host in seq";

    my $w = AnyEvent->timer( after => 0.1, cb => sub {
          # Crunch, crunch, crunch. Task done. Report back.
        DEBUG "Sending task_mark_done for task $task back to scheduler";
        $scheduler->event( "task_mark_done", $task );
    } );

    push @timers, $w;

    $bck->all_done and $cv->send(); # quit
} );

  # schedule all hosts
$scheduler->schedule( [ $scheduler->config_hosts() ] );

$cv->recv;
