#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;

my $nof_tests = 1;
plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG, category => 'main' } );

use Pogo::Scheduler::Config;

my $cfg = Pogo::Scheduler::Config->new();

$cfg->load( <<'EOT' );
tag:
  $colo.usa:
    - host1
  $colo.mexico:
    - host2
EOT

ok 1, "done";

#my @all = $cfg->members( "colo" );           # host1, host2
#my @mexico = $cfg->members( "colo.mexico" ); # host2
