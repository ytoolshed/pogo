
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoFake;
use PogoTest;
use Test::More;
use Log::Log4perl qw(:easy);
use Getopt::Std;
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
);

my $pogo;

my $cdir = "$Bin/certs";

# $Object::Event::DEBUG = 2;

$pogo = PogoFake->new(
    ssl              => 1,
    worker_key       => "$cdir/worker.key",
    worker_cert      => "$cdir/worker.crt",
    dispatcher_key   => "$cdir/dispatcher.key",
    dispatcher_cert  => "$cdir/dispatcher.crt",
    ca_cert          => "$cdir/ca.crt",
);

#$pogo->reg_cb( worker_dconn_error  => sub {
#    LOGDIE @_;
#} );

$pogo->reg_cb( worker_dconn_connected  => sub {
    my( $c, $worker ) = @_;

    ok( 1, "worker connected #4" );
    is( $worker, $POGO_DISPATCHER_WORKERCONN_HOST, "worker host #5" );
});

$pogo->reg_cb( dispatcher_wconn_worker_connect  => sub {
    my( $c, $worker ) = @_;

    ok( 1, "dispatcher: worker connected #1" );
    is( $worker, $POGO_DISPATCHER_WORKERCONN_HOST, "worker host #3" );
});

$pogo->reg_cb( dispatcher_wconn_prepare => sub {
   my( $c, $host, $port ) = @_;

   DEBUG "received dispatcher_prepare";

   is( "$host:$port",
      "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT",
      "dispatcher server_prepare cb #2" );
});

plan tests => 5;

$pogo->start();
