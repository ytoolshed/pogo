
use warnings;
use strict;
use AnyEvent;
use Pogo::Plugin;
use Test::More;

plan tests => 1;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
}

#require Pogo::AnyEvent::ZooKeeper;

my $cv = AnyEvent->condvar();

my $zk;

# $zk = Pogo::AnyEvent::ZooKeeper->new(
#     connected => sub {
#         $zk->create( "/foo", sub { } );
#         $zk->set( "/foo", "bar", sub { } );
#         
#         is $zk->get( "/foo" ), "bar", "zk set/get";
#         $cv->send();
#     },
# );

ok 1, "test";

# $cv->recv();
