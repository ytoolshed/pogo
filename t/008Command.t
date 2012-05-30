
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";
use Pogo::Worker::Task::Command;

use PogoTest;
use PogoFake;
use Test::More;
use Log::Log4perl qw(:easy);
use Getopt::Std;

plan tests => 2;

my $cv = AnyEvent->condvar;

my $cmd = Pogo::Worker::Task::Command->new(
    cmd => "echo meh; sleep 2; echo bah",
);

my @exp = ( "meh\n", "bah\n" );
$cmd->reg_cb( "on_stdout", sub {
    my( $c, $data ) = @_;
    
    DEBUG "received: $_[1]";

    my $exp = shift @exp;
    is( $data, $exp, "expected stdout data" );

    if( !@exp ) {
        $cv->send();
    }
});

$cmd->start();
$cv->recv();
