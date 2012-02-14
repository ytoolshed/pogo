
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

BEGIN {
      # to find the templates in t/tmpl
    chdir $Bin;
}

use PogoOne;
use PogoTest;
use AnyEvent::HTTP;
use Test::More;
use Log::Log4perl qw(:easy);
use Getopt::Std;
use Pogo::Defaults qw(
  $POGO_DISPATCHER_API_PORT
);

my $pogo;

$pogo = PogoOne->new();

$pogo->reg_cb( dispatcher_api_up  => sub {
    my( $c ) = @_;

    ok( 1, "dispatcher api up #1" );
});

$pogo->reg_cb( dispatcher_api_up  => sub {
    my( $c ) = @_;

    http_get "http://localhost:$POGO_DISPATCHER_API_PORT", sub { 
        my( $html ) = @_;

        like $html, qr/Hello there/, "HTTP request to API \#2";
    };
});

plan tests => 2;

$pogo->start();
