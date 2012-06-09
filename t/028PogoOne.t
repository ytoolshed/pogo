#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;

my $nof_tests = 3;
plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Pogo::One;
use Pogo::Job;
use Pogo::Util::Bucketeer;

# use Log::Log4perl qw(:easy);
# Log::Log4perl->easy_init( { level => $DEBUG, category => 'main' } );

my $main = AnyEvent->condvar();

my $pogo = Pogo::One->new();

my $job = Pogo::Job->new(
    command  => "test",
    range    => [ qw(host1 host2) ],
    config   => <<'EOT',
tag:
sequence:
  - host3
  - host2
  - host1
EOT
);

$pogo->reg_cb( "pogo_one_job_submitted", sub {
    my( $c, $job ) = @_;

    ok 1, "job submitted #1";
} );

$pogo->reg_cb( "pogo_one_ready", sub {

    $pogo->job_submit( 
        $job,
    );
} );

my $bck = Pogo::Util::Bucketeer->new(
    buckets => [
  [ qw( host2 ) ],
  [ qw( host1 ) ],
] );

$pogo->reg_cb( "worker_task_active", sub {
        my( $c, $task ) = @_;

        DEBUG "Worker running task ", $task->as_string();
} );

my $seq = 0;

$pogo->reg_cb( "worker_task_done", sub {
        my( $c, $task) = @_;

        DEBUG "Worker done with task ", $task->id();
        $seq++;
        my $host = $task->host();
        ok $bck->item( $host ), "host $host in seq #$seq";

        if( $seq == 2 ) {
            $main->send();
        }
} );

$pogo->start();
$main->recv();
