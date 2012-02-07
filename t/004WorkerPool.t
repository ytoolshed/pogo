
use strict; 
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoOne;
use Test::More;
use Log::Log4perl qw(:easy);
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
);

# Log::Log4perl->easy_init({ level => $DEBUG, layout => "%F{1}-%L: %m%n" });

my $pogo;

$pogo = PogoOne->new();

  # second worker
my $worker2 = Pogo::Worker->new(
    delay_connect => 0,
    dispatchers => [
    "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT" ]
);

$pogo->reg_cb( dispatcher_wconn_worker_connect  => sub {
    my( $c, $worker ) = @_;

    ok( 1, "worker connected" );
});

$worker2->start();

plan tests => 2;

$pogo->start();
