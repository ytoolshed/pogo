
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoOne;
use Test::More;
use Log::Log4perl qw(:easy);
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
  $POGO_DISPATCHER_RPC_HOST
  $POGO_DISPATCHER_RPC_PORT
);

Log::Log4perl->easy_init({ level => $DEBUG, layout => "%F{1}-%L: %m%n" });

my $pogo;

$pogo = PogoOne->new();

$pogo->reg_cb( worker_connect  => sub {
    my( $c, $worker ) = @_;

    ok( 1, "worker connected" );
    is( $worker, $POGO_DISPATCHER_WORKERCONN_HOST, "worker host" );
});

$pogo->reg_cb( dispatcher_prepare => sub {
   my( $c, $host, $port ) = @_;

   DEBUG "received dispatcher_prepare";

   is( "$host:$port",
      "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT",
      "dispatcher server_prepare cb" );
});

plan tests => 3;

$pogo->start();
