
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";
use Pogo::Worker::Task::Command;
use Sysadm::Install qw( bin_find );

use PogoTest;
use PogoFake;
use Test::More;
use Log::Log4perl qw(:easy);
use Getopt::Std;

my $echo = bin_find( "echo" );

plan tests => 4;

my $cv = AnyEvent->condvar;

my $TEST_ID = "some-id";

my $task = Pogo::Worker::Task::Command->new(
    command => "$echo foo; $echo bar",
    id      => $TEST_ID,
);

my $gobbled_up = "";

$task->reg_cb( "on_stdout", sub {
    my( $c, $data ) = @_;

    $gobbled_up .= $data;
});

$task->reg_cb( "on_finish", sub {
    my( $c ) = @_;

    is $c->rc(), 0, "success";

    my $expected = "foo\nbar\n";
    is $gobbled_up, $expected, "expected stdout data";
    is $c->stdout(), $expected, "stdout() call";

    is $c->id(), $TEST_ID, "task id ok";
    $cv->send();
});

$task->start();
$cv->recv();
