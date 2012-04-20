
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

use Pogo::Scheduler::Classic;
my $scheduler = Pogo::Scheduler::Classic->new();

my $cv = AnyEvent->condvar();

$scheduler->config_load( \ <<'EOT' );
tag:
  colo:
    north_america:
      - host4
      - host5
      - host6
      - host7
      - host8
      - host9
      - host10
      - host11
      - host12

constraint:
    $colo.north_america: 
       max_parallel: 1
EOT

print $scheduler->as_ascii(), "\n";
 
my $max = 1;
my $hosts_scheduled = 0;

$scheduler->reg_cb( "task_run", sub {
    my( $c, $task ) = @_;

    my $host = $task->{ host };

    $hosts_scheduled++;

    if( $hosts_scheduled > $max ) {
        die "Constraint violated, $hosts_scheduled hosts scheduled but ",
            "only $max allowed.";
    }

    ok 1, "got host $task";
} );

$scheduler->reg_cb( "waiting", sub {
    my( $c, $thread, $slot ) = @_;

    DEBUG "Waiting on thread $thread slot $slot";
    ok 1, "waiting";

    $cv->send();
} );

  # schedule all hosts
$scheduler->schedule( [ $scheduler->config_hosts() ] );

$cv->recv;
