 
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoOne;
use Test::More;
use Getopt::Std;
use Log::Log4perl qw(:easy);

getopts( "v", \my %opts );

if( $opts{ v } ) {
    Log::Log4perl->easy_init({ level => $DEBUG, layout => "%F{2}-%L: %m%n" });
    DEBUG "Verbose mode";
}

my $pogo;

$pogo = PogoOne->new();

$pogo->reg_cb( worker_dconn_cmd_recv  => sub {
    my( $c, $data ) = @_;

    DEBUG "Dispatcher received command";

    is( $data->{ cmd }, "my-command", "received worker command" );
});

$pogo->reg_cb( dispatcher_wconn_worker_cmd_recv  => sub {
    my( $c, $data ) = @_;

    DEBUG "Dispatcher received command";

    is( $data->{ cmd }, "my-command", "received worker command" );
});

plan tests => 3;

$pogo->reg_cb( worker_dconn_listening => sub {
      
    DEBUG "Dispatcher listening, triggering worker command";
    $pogo->{ worker }->to_dispatcher( { cmd => "my-command" } );
});

$pogo->reg_cb( worker_dconn_ack => sub {
    my( $c ) = @_;

    ok 1, "ok ack";
} );

$pogo->reg_cb( worker_dconn_qp_idle => sub {
    my( $c ) = @_;

    ok 1, "qp idle";

    $pogo->quit();
} );

$pogo->start();
