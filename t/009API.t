
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoTest;
use PogoOne;
use Test::More;
use Log::Log4perl qw(:easy);
use Getopt::Std;
use Pogo::API;
use JSON qw(from_json);

plan tests => 3;

  # dispatcher/worker
my $pogo = PogoOne->new();

  # api server
my $api_server = Pogo::API->new();

my %waiting_for = map { $_ => 1 } qw( worker api );

$api_server->reg_cb( api_server_up  => sub {
    my( $c ) = @_;
    DEBUG "api ready";
    delete $waiting_for{ "api" };
    $pogo->event( "check_test_ready" );
});

$api_server->standalone();

$pogo->reg_cb( check_test_ready => sub { 
    if( scalar keys %waiting_for ) {
        DEBUG "Still missing: ", join( "-", keys %waiting_for );
    } else {
        run_tests();
    }
} );

$pogo->reg_cb( dispatcher_wconn_worker_connect  => sub {
    my( $c, $worker ) = @_;
    DEBUG "worker ready";
    delete $waiting_for{ "worker" };
    $pogo->event( "check_test_ready" );
});

$pogo->start();

####################################
sub run_tests {
####################################
    ok 1, "all components required for test are up #1";

    $pogo->reg_cb( dispatcher_job_received => sub {
        my( $c, $cmd ) = @_;
        is $cmd, "ls", "dispatcher job received event #3";
    });

    use AnyEvent::HTTP;
    my $base_url = $api_server->base_url();
    http_get "$base_url/jobsubmit?cmd=ls", sub { 
        my( $body, $hdr ) = @_;

        my $data = from_json( $body );
        is $data->{ message }, "dispatcher CP: job received", 
            "received ack from dispatcher CP #2";
    };
}
