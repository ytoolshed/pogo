
use warnings;
use strict;
use Test::More;
use Log::Log4perl qw(:easy);

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
  - $colo.north_america
  - $colo.south_east_asia
EOT

my %expected = map { $_ => 1 } qw( host1 host2 host3 );

my $nof_tasks_received = 0;

$scheduler->reg_cb( "task_run", sub {
    my( $c, $task ) = @_;

    DEBUG "Received task $task to run";
    DEBUG "Expected: [", join( ", ", keys %expected ), "]";

    if( !scalar keys %expected ) {
          # we've gotten the first batch, allow the second
        DEBUG "Resetting %expected for 2nd half";
        %expected = map { $_ => 1 } qw( host4 host5 host6 );
    }

    if( exists $expected{ $task } ) {
        my( $num ) = ( $task =~ /(\d+)/ );
        ok 1, "Received task $task (expected) #$num";
        delete $expected{ $task };

        $nof_tasks_received++;

          # Crunch, crunch, crunch. Task done. Report back.
        $scheduler->event( "task_finished", $task );

        if( $nof_tasks_received == $nof_tests ) {
            $cv->send(); # quit
        }
    }
} );

for my $hostid ( reverse 1..6 ) {
    $scheduler->task_add( "host$hostid" );
}

$scheduler->start();

$cv->recv;
