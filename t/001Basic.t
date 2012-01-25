use warnings;
use strict;

use Test::More;
use Log::Log4perl qw(:easy);
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
  $POGO_DISPATCHER_RPC_HOST
  $POGO_DISPATCHER_RPC_PORT
);

Log::Log4perl->easy_init($DEBUG);

plan tests => 3;

use Pogo::Dispatcher;
use Pogo::Worker;

my $MAIN = AnyEvent->condvar;

my $worker = Pogo::Worker->new(
    dispatchers => [ 
      "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT" ]
);

my $dispatcher = Pogo::Dispatcher->new();

my $dispatch_hostport = "";
$dispatcher->reg_cb( "server_prepare", sub {
        my( $self, $host, $port ) = @_;
        $dispatch_hostport = "$host:$port";
});
$dispatcher->reg_cb( "worker_connect", sub {
        my( $self, $host ) = @_;

        is( $host, $POGO_DISPATCHER_WORKERCONN_HOST, 
            "worker $POGO_DISPATCHER_WORKERCONN_HOST connected" );
          # terminate main event loop
        $MAIN->send();
});

$worker->start();
$dispatcher->start();

ok( 1, "started up" );
is( $dispatch_hostport,
   "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT",
   "dispatcher server_prepare cb" );

  # start event loop
$MAIN->recv();
