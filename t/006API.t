
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";
use JSON qw( from_json );

BEGIN {
      # to find the templates in t/tmpl
    chdir $Bin;
}

use PogoOne;
use PogoTest;
use AnyEvent::HTTP;
use Test::More;
use Log::Log4perl qw(:easy);
use Getopt::Std;
use Pogo::Defaults qw(
  $POGO_DISPATCHER_API_PORT
  $POGO_DISPATCHER_API_HOST
);

my $pogo;

$pogo = PogoOne->new();

$pogo->reg_cb( dispatcher_api_up  => sub {
    my( $c ) = @_;

    ok( 1, "dispatcher api up #1" );
});

$pogo->reg_cb( dispatcher_wconn_worker_connect  => sub {
    my( $c ) = @_;

    http_get 
     "http://$POGO_DISPATCHER_API_HOST:$POGO_DISPATCHER_API_PORT/status", 
     sub { 
            my( $html ) = @_;
 
            my $data = from_json( $html );

            my @workers = @{ $data->{ workers } };

            is scalar @workers, 1, "One worker connected \#2";
            like $workers[0], 
              qr/$POGO_DISPATCHER_API_HOST:\d+$/, "worker details \#3";
     };
});

plan tests => 3;

$pogo->start();
