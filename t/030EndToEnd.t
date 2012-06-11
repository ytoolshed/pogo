#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;

my $nof_tests = 4;
plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Pogo::One;
use Pogo::Client::Async;
use Pogo::Job;
use Pogo::Util::Bucketeer;
use Data::Dumper;
use Pogo::Util::Bucketeer;

# use Log::Log4perl qw(:easy);
# Log::Log4perl->easy_init( { level => $DEBUG, category => 'main' } );

my $main = AnyEvent->condvar();

my $pogo = Pogo::One->new(
    ssh => "$Bin/../bin/pogo-test-ssh-sim",
);

my $client = Pogo::Client::Async->new(
    api_base_url => $pogo->api_server()->base_url(),
);

my $bck = Pogo::Util::Bucketeer->new(
    buckets => [
  [ qw( host2 ) ],
  [ qw( host1 ) ],
] );

$client->reg_cb( "client_job_submit_ok", sub {
    my( $c, $resp, $job ) = @_;
    INFO "Job submitted.";
} );

$client->reg_cb( "client_job_submit_fail", sub {
    my( $c, $resp, $job ) = @_;
    ERROR "Job submission failed: ", Dumper( $resp );
    $main->send();
} );

my $job = Pogo::Job->new(
    task_name => "ssh",
    range     => [ qw(host1 host2) ],
    command   => "date",
    config    => <<'EOT',
tag:
sequence:
  - host3
  - host2
  - host1
EOT
);

$pogo->reg_cb( "pogo_one_ready", sub {
    DEBUG "Pogo one is ready.";

    $client->job_submit( $job->as_hash() );
} );

my $seq = 0;

$pogo->reg_cb( worker_task_done => sub {
    my( $c, $task ) = @_;

    DEBUG "Worker done with task ", $task->id();
    $seq++;

    my $task_string = $task->as_string();
    my $host = $task->host();

    ok $bck->item( $host ), "host $host in seq #$seq";

    if( $seq == 2 ) {
        $main->send();
    }

    is $task->rc(), 0, "worker command succeeded ($host)";
});

$pogo->start();
$main->recv();
