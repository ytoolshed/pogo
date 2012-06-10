 
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoFake;
use PogoTest;
use Test::More;
use Getopt::Std;
use Log::Log4perl qw(:easy);

my $pogo;

$pogo = PogoFake->new();

$pogo->reg_cb( worker_dconn_cmd_recv  => sub {
    my( $c, $task_id, $data ) = @_;

    DEBUG "Worker received command";

    is( $data->{ command }, "command-by-dispatcher", 
        "received dispatcher command #1" );
});

$pogo->reg_cb( dispatcher_wconn_cmd_recv  => sub {
    my( $c, $data ) = @_;

    DEBUG "Dispatcher received command";

    return if $data->{ command } ne "command-by-worker";

    is( $data->{ command }, 
        "command-by-worker", "received worker command #2" );
});

plan tests => 5;

$pogo->reg_cb( worker_dconn_listening => sub {
      
    DEBUG "Dispatcher listening, triggering worker command";
    $pogo->{ worker }->to_dispatcher( { command => "command-by-worker",
                                        task_id => "123" } );
});

my $dconn_acks = 0;

$pogo->reg_cb( worker_dconn_ack => sub {
    my( $c ) = @_;

    return if $dconn_acks++ > 0;

    ok 1, "worker got dispatcher ack #3";
} );

$pogo->reg_cb( dispatcher_wconn_ack => sub {
    my( $c ) = @_;

    ok 1, "dispatcher got worker ack #4";
} );

$pogo->reg_cb( worker_dconn_qp_idle => sub {
    my( $c ) = @_;

    ok 1, "qp idle #5";
} );

$pogo->reg_cb( dispatcher_wconn_worker_connect => sub {
      
    DEBUG "Connection up, dispatcher sending command to worker";
    $pogo->{ dispatcher }->to_worker( { task_data => {
                                         task_name => "blech",
                                         command   => "command-by-dispatcher",
                                        },
                                        task_id => "123" } );
});

$pogo->start();
