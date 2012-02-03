 
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoOne;
use Test::More;
use Log::Log4perl qw(:easy);

# Log::Log4perl->easy_init({ level => $DEBUG, layout => "%F{1}-%L: %m%n" });

my $pogo;

$pogo = PogoOne->new();

$pogo->reg_cb( worker_command  => sub {
    my( $c, $data ) = @_;

    DEBUG "Test suite received worker command";

    is( $data->{ cmd }, "whoa", "received worker command" );
});

plan tests => 2;

$pogo->reg_cb( worker_dispatcher_listening => sub {
      
    DEBUG "Dispatcher listening, triggering worker command";
    $pogo->{ worker }->to_dispatcher( { cmd => "whoa" } );
});

$pogo->reg_cb( worker_dispatcher_ack => sub {
    my( $c ) = @_;

    ok 1, "ok ack";
} );

$pogo->reg_cb( worker_dispatcher_qp_idle => sub {
    my( $c ) = @_;

    ok 1, "qp idle";

    $pogo->quit();
} );

$pogo->start();
