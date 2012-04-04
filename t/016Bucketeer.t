
use warnings;
use strict;
use Test::More;
use Log::Log4perl qw(:easy);

my $nof_tests = 9;

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

ok !$bkt->all_done(), "not all done";

ok $bkt->item( "host2" ), "host2 in seq";
ok $bkt->item( "host1" ), "host1 in seq"; 
ok !$bkt->item( "host4" ), "host4 out of seq";

ok !$bkt->all_done(), "not all done";

ok $bkt->item( "host3" ), "host3 in seq";
ok $bkt->item( "host4" ), "host4 in seq";
ok $bkt->item( "host5" ), "host5 in seq";
ok $bkt->all_done(), "all done";
