
use warnings;
use strict;
use Pogo::Plugin;
use Test::More;

plan tests => 2;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
}

my $plugins = Pogo::Plugin->load( "Test" );

ok defined $plugins, "found plugin";

is ref $plugins, "Pogo::Plugin::Test::Default", "found default plugin";
