
use warnings;
use strict;
use AnyEvent;
use Pogo::Plugin;
use Test::More;
use Log::Log4perl qw(:easy);
use Pogo::Util::Bucketeer;
use Test::Deep;
use YAML qw(Load);

my $nof_tests = 1;

plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Pogo::Scheduler::Classic;
my $scheduler = Pogo::Scheduler::Classic->new();

my $cv = AnyEvent->condvar();

my $data = <<'EOT';
tag:
  frontend:
    - host1
    - host4
  backend: 
    - host2
    - host5
  colo:
    north_america:
      - host1
      - host2
      - host3
    south_east_asia:
      - host4
      - host5
      - host6
sequence:
  $frontend:
    - $colo.north_america
    - $colo.south_east_asia
  $backend:
    - $colo.south_east_asia
    - $colo.north_america
EOT

my $struct = { a => { b => [ qw(c d) ] } };

my $paths = $scheduler->leaf_paths( $struct );

cmp_deeply( $paths, [ [qw(a b d)], [qw(a b c)] ], "leaf_paths" );

__END__

$scheduler->config_load( \$data ) or 
    die "Failed ot load config";

use Data::Dumper;
print Dumper( $scheduler );

__END__
  # only frontends need to be in sequence, everything else can go
  # in parallel
my $bck = Pogo::Util::Bucketeer->new(
    buckets => [
        [ qw( host1 host2 host3 host5 host6 ) ],
        [ qw( host4 ) ],
    ],
);

$scheduler->reg_cb( "task_run", sub {
    my( $c, $task ) = @_;

    ok $bck->item( $task ), "task $task in sync";

    $bck->all_done() and $cv->send(); # quit
} );

for my $task ( $bck->items() ) {
    $scheduler->task_add( $task );
}

$scheduler->start();

$cv->recv;
