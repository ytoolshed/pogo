
use strict; 
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use Test::More;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use PogoTest;

our $nof_tests;

BEGIN {
    eval q{use Net::ZooKeeper};

    if( $@ ) {
        plan skip_all => "Net::ZooKeeper not installed";
    } else {
        our $nof_tests = 2;
        plan tests => $nof_tests;
    }
}

use Pogo::AnyEvent::ZooKeeper; 
use Net::ZooKeeper qw(:errors :node_flags :acls);

my $zk = Pogo::AnyEvent::ZooKeeper->new();

my $testpath = "/test-123";

SKIP: {

  my $cv = AnyEvent->condvar;

  $zk->reg_cb( "zk_connect_error", sub { $cv->send(); });
  $zk->reg_cb( "zk_connect_ok", sub { $cv->send(); });
  $zk->start();

  $cv->recv();

  if( ! $zk->ping() ) {
      skip "No ZooKeeper running on " . $zk->netloc(), $nof_tests;
  }
  
  ok 1, "ZooKeeper up on " . $zk->netloc();

  my $del = AnyEvent->condvar();
  $zk->delete( $testpath, sub {
      $del->send();
  } );
  $del->recv();

  $zk->create( $testpath, "blech-value", 
               'flags' => ZOO_EPHEMERAL,
               'acl'   => ZOO_OPEN_ACL_UNSAFE,
                sub {
                    my( $c, $rc ) = @_;
                    is $rc, $testpath, "create";
                } );
}
