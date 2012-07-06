#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;

my $nof_tests = 2;
plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Log::Log4perl qw(:easy);
# Log::Log4perl->easy_init( { level => $DEBUG, category => 'main' } );

use Pogo::Util::Cache;
my $cache = Pogo::Util::Cache->new( expire => 0.1 );

$cache->set( "foo", "bar" );

is $cache->get( "foo" ), "bar", "item cached";

my $cv = AnyEvent->condvar();

my $timer = AnyEvent->timer( after => 0.2, cb => sub {
    is $cache->get( "foo" ), undef, "item expired";
    $cv->send();
} );

$cv->recv();
