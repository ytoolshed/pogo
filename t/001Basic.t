use warnings;
use strict;

use Test::More;
use Log::Log4perl qw(:easy);
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
);

Log::Log4perl->easy_init($DEBUG);

plan tests => 2;

use Pogo::Dispatcher;
use Pogo::Worker;

my $guard = AnyEvent->condvar;

my $worker = Pogo::Worker->new(
);

my $dispatcher = Pogo::Dispatcher->new();

my $dispatch_hostport = "";
$dispatcher->reg_cb( "server_prepare", sub {
        my($self, $host, $port) = @_;
        $dispatch_hostport = "$host:$port";
});

$worker->start();
$dispatcher->start();

ok( 1, "started up" );
is( $dispatch_hostport,
   "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT",
   "dispatcher server_prepare cb" );

  # start event loop
# $guard->recv();
