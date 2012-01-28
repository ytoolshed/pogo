
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

plan tests => 1;

$pogo->reg_cb( worker_dispatcher_listening => sub {
      
    DEBUG "Dispatcher listening, triggering worker command";
    $pogo->{ worker }->cmd_send( { channel => 1, cmd => "whoa" } );
});

$pogo->reg_cb( worker_dispatcher_control_message => sub {
    my( $c, $data ) = @_;

    if( exists $data->{ ok } ) {
        is $data->{ msg }, "OK", "ok confirmation";
        $pogo->quit();
    }
} );

$pogo->start();
