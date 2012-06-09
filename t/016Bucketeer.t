
use warnings;
use strict;
use Test::More;
use Log::Log4perl qw(:easy);

my $nof_tests = 12;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

plan tests => $nof_tests;

use Pogo::Util::Bucketeer;

my $bkt = Pogo::Util::Bucketeer->new(
  buckets => [
    [ qw( host1 host2 host3 ) ],
    [ qw( host4 host5 ) ],
  ]
);

my $bkt2 = Pogo::Util::Bucketeer->new(
  buckets => [
    [ qw( host10 host12 ) ],
  ]
);

my $thread = Pogo::Util::Bucketeer::Threaded->new();
$thread->bucketeer_add( $bkt );
$thread->bucketeer_add( $bkt2 );

ok !$thread->all_done(), "not all done";

ok $thread->item( "host2" ), "host2 in seq";
ok $thread->item( "host1" ), "host1 in seq"; 
ok !$thread->item( "host4" ), "host4 out of seq";

ok !$thread->all_done(), "not all done";

ok $thread->item( "host3" ), "host3 in seq";
ok $thread->item( "host4" ), "host4 in seq";
ok $thread->item( "host5" ), "host5 in seq";
ok !$thread->all_done(), "not all done";

ok $thread->item( "host12" ), "host11 (thread2) in seq";
ok $thread->item( "host10" ), "host10 (thread2) in seq"; 

ok $thread->all_done(), "all done";
