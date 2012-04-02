
use warnings;
use strict;
use AnyEvent;
use Pogo::Plugin;
use Test::More;
use Log::Log4perl qw(:easy);

plan tests => 6;

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

my %expected = map { $_ => 1 } qw( host1 host2 host3 );

$s->reg_cb( "task_run", sub {
    my( $c, $task ) = @_;

    ok exists $expected{ $task }, "Received task $task (expected)";

    if( !scalar keys %expected ) {
          # we've gotten the first batch, allow the second
        %expected = map { $_ => 1 } qw( host4 host5 host6 );
    }
} );

for my $hostid ( reverse 1..6 ) {
    $s->task_add( "host$hostid" );
}
