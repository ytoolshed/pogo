
use strict; 
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use Test::More;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use PogoTest;
use Pogo::AnyEvent::ZooKeeper;

my $nof_tests = 1;
plan tests => $nof_tests;

my $zk = Pogo::AnyEvent::ZooKeeper->new();

SKIP: {

  my $cv = AnyEvent->condvar;

  $zk->reg_cb( "zk_connect_error", sub { $cv->send(); });
  $zk->reg_cb( "zk_connect_ok", sub { $cv->send(); });
  $zk->start();

  $cv->recv();

  if( ! $zk->ping() ) {
      skip "No ZooKeeper running", $nof_tests;
  }
  
  ok 1, "ZooKeeper up on " . $zk->netloc();
}
