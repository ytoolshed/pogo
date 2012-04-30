
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";
use JSON qw( from_json );
use Pogo::API;

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
  $POGO_DISPATCHER_CONTROLPORT_PORT
  $POGO_DISPATCHER_CONTROLPORT_HOST
  $POGO_API_TEST_PORT
  $POGO_API_TEST_HOST
);

my $pogo;

$pogo = PogoOne->new();

$pogo->reg_cb( dispatcher_controlport_up  => sub {
    my( $c ) = @_;

    ok( 1, "dispatcher controlport up #1" );
});

$pogo->reg_cb( dispatcher_wconn_worker_connect  => sub {
    my( $c ) = @_;

    http_get 
     "http://$POGO_DISPATCHER_CONTROLPORT_HOST:" .
     "$POGO_DISPATCHER_CONTROLPORT_PORT/status", 
     sub { 
            my( $html ) = @_;
 
            DEBUG "Response from server: [$html]";

            my $data = from_json( $html );

            my @workers = @{ $data->{ workers } };

            is scalar @workers, 1, "One worker connected \#2";
            like $workers[0], 
              qr/$POGO_DISPATCHER_CONTROLPORT_HOST:\d+$/, "worker details \#3";
 
            is $data->{ pogo_version }, $Pogo::VERSION, "pogo version \#4";
     };
});

  # Start up test API server
my $api = Plack::Handler::AnyEvent::HTTPD->new(
    host => $POGO_API_TEST_HOST,
    port => $POGO_API_TEST_PORT,
    server_ready => 
      tests( "http://$POGO_API_TEST_HOST:$POGO_API_TEST_PORT" ),
);

$api->register_service( Pogo::API->app() );

plan tests => 6;

$pogo->start();

  # This gets called once the API server is up
sub tests {
    my( $base_url ) = @_;

    return sub {
        http_get "$base_url/status", sub {
           my( $html ) = @_;
           my $data = from_json( $html );
           is $data->{ pogo_version }, $Pogo::VERSION, "pogo version \#5";
        };

        http_get "$base_url/v1/ping", sub {
           my( $html ) = @_;
           my $data = from_json( $html );
           is $data->{ message }, 'pong', "ping ponged \#6";
        };
    };
}
