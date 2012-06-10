
use strict; 
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoFake;
use PogoTest;
use Test::More;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
);

my $pogo;

$pogo = PogoFake->new();

  # second worker
my $worker2 = Pogo::Worker->new(
    delay_connect => sub { 0 },
    dispatchers => [
    "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT" ]
);

my $workers_connected = 0;

$pogo->reg_cb( dispatcher_wconn_worker_connect  => sub {
    my( $c, $worker ) = @_;

    $workers_connected++;

    ok( 1, "worker $workers_connected connected" );

    if( $workers_connected == 2 ) {
        $pogo->{ dispatcher }->to_worker( { 
                task_data => {
                    task_name => "test",
                    command => "command-by-dispatcher",
                },
                task_id => 123 } );
    }
});

$worker2->start();

my $cmds_received = 0;

$pogo->{ worker }->reg_cb( "worker_dconn_cmd_recv", sub {
    my( $c, $cmd ) = @_;

    DEBUG "First worker received: ", Dumper( $cmd );
    is ++$cmds_received, 1, "command received by *one* worker";
} );

$worker2->reg_cb( "worker_dconn_cmd_recv", sub {
    my( $c, $cmd ) = @_;

    DEBUG "Second worker received: ", Dumper( $cmd );
    is ++$cmds_received, 1, "command received by *one* worker";
} );

plan tests => 3;

$pogo->start();
