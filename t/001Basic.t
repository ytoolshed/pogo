use warnings;
use strict;

use Test::More;

plan tests => 1;

use Pogo::Dispatcher;
use Pogo::Worker;

my $guard = AnyEvent->condvar;

my $worker = Pogo::Worker->new(
    on_connect => sub {
    },
);

my $dispatcher = Pogo::Dispatcher->new(
    on_worker => sub {
    },
);

$worker->start();
$dispatcher->start();

ok(1, "started up");

  # start event loop
#$guard->recv();

