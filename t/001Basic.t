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
my $WORKER_HOST = "";
my $DISPATCH_HOSTPORT = "";

my $worker = Pogo::Worker->new(
    delay_connect => 0,
    dispatchers => [ 
      "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT" ]
);

my $dispatcher = Pogo::Dispatcher->new();

$dispatcher->reg_cb( "server_prepare", sub {
        my( $self, $host, $port ) = @_;
        $DISPATCH_HOSTPORT = "$host:$port";
          # start worker when dispatcher is ready
        $worker->start();
});
$dispatcher->reg_cb( "worker_connect", sub {
        my( $self, $host ) = @_;

        $WORKER_HOST = $host;
        run_tests();
          # terminate main event loop
        $MAIN->send();
});

    my $timer;
    $timer = AnyEvent->timer(
        after => 1,
        cb    => sub {
            undef $timer;
            $dispatcher->start();
        }
    );


ok( 1, "started up" );

  # start event loop
$MAIN->recv();

###########################################
sub run_tests {
###########################################

    is( $DISPATCH_HOSTPORT,
       "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT",
       "dispatcher server_prepare cb" );

    is( $WORKER_HOST, $POGO_DISPATCHER_WORKERCONN_HOST, 
        "worker $POGO_DISPATCHER_WORKERCONN_HOST connected" );

}
