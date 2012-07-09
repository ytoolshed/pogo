#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;

my $nof_tests = 7;
plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Log::Log4perl qw(:easy);
# Log::Log4perl->easy_init( { level => $DEBUG, category => 'main' } );
# Log::Log4perl->easy_init( $DEBUG );

use Pogo::Scheduler::Config;

my $cfg = Pogo::Scheduler::Config->new();

$cfg->load( <<'EOT' );
tag:
  colo.usa:
    - host1
  colo.mexico:
    - host2
EOT

my $members = $cfg->members( "colo" );           # host1, host2

is scalar @$members, 2, "member ok";
is $members->[0], "host1", "member ok";
is $members->[1], "host2", "member ok";

my $mexico = $cfg->members( "colo.mexico" ); # host2

is scalar @$mexico, 1, "child ok";
is $mexico->[0], "host2", "child ok";

# custom tag resolver
$members = $cfg->members( "Example bonk schtonk" );
is $members->[0], "foo", "external tag resolver member ok";
is $members->[1], "bar", "external tag resolver member ok";
