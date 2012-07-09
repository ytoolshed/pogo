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
# Log::Log4perl->easy_init( { level => $DEBUG, category => 'main' } );
# Log::Log4perl->easy_init( $DEBUG );

use Pogo::Plugin;
my $tagex = Pogo::Plugin->load('TagExternal',{ 
        required_methods => [ 'members' ] } );

my $members = $tagex->members( "Example", "bonkgroup" );

is $members->[0], "foo", "example plugin";
