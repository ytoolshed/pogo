
use warnings;
use strict;
use AnyEvent;
use Pogo::Plugin;
use Test::More;
use Test::Deep;
use Log::Log4perl qw(:easy);

plan tests => 3;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Pogo::Scheduler::Classic;

my $s = Pogo::Scheduler::Classic->new();

$s->config_load( \ <<'EOT' );
tag:
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
  - $colo.north_america
  - $colo.south_east_asia
EOT

my $cfg = $s->config();

is "$cfg->{ sequence }->[0]", '$colo.north_america', "config sequence";
is "$cfg->{ sequence }->[1]", '$colo.south_east_asia', "config sequence";

my $struct = { a => { b => [ qw(c d) ] } };

my $paths = [];

Pogo::Util::struct_traverse( $struct, { 
    leaf => sub {
        my( $node, $path ) = @_; 

        push @$paths, [@$path, $node];
    } 
} );

cmp_deeply( $paths, [ [qw(a b d)], [qw(a b c)] ], "leaf_paths" );

