
use warnings;
use strict;
use AnyEvent;
use Pogo::Plugin;
use Test::More;
use Log::Log4perl qw(:easy);

plan tests => 1;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

require Pogo::AnyEvent::ZooKeeper;

my $cv = AnyEvent->condvar();

my $zk;

$zk = Pogo::AnyEvent::ZooKeeper->new( "bogushost" );
$zk->reg_cb(
    zk_connect_ok => sub {

        my $zv = AnyEvent->condvar();
        $zk->create( "/foo", sub { $zv->send() } );
        DEBUG "Waiting for create";
        $zv->recv();

        $zv = AnyEvent->condvar();
        $zk->set( "/foo", "bar", sub { $zv->send() } );
        DEBUG "Waiting for set";
        $zv->recv();
        
        my $value;
        $zv = AnyEvent->condvar();
        $zk->get( "/foo", sub { $value = $_[1] } );
        DEBUG "Waiting for get";
        $zv->recv();

        DEBUG "Testing";
        is $value, "bar", "zk set/get";
        $cv->send();
    },
);

ok 1, "test";

DEBUG "Starting up";
$zk->start();

$cv->recv();
