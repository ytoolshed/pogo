#!/usr/bin/env perl -w
# $Id: 00_mojolicious.t 283310 2010-09-05 16:41:19Z nharteau $
# vim:ft=perl:

# Testing Mojolicious
use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw/GET POST/;
use Test::More tests => 5;
use FindBin qw($Bin);
use File::Slurp qw/slurp/;

use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoTest;

ok( Log::Log4perl::init("$Bin/conf/log4perl.conf"), "log4perl" );
ok( PogoTest::start_mojo(),                              'start_mojo' );

my ( $req, $resp );
my $ua = LWP::UserAgent->new();

$req  = GET 'http://localhost:3000/foo';
$resp = $ua->request($req);

is( $resp->content, 'bar', 'Mojolicious' );

my $tdata = slurp("$Bin/data/stub-roles-range-mailapps.js");

$req = POST
  'http://localhost:3000/roles/v1/range/%40mail.farm.app.fe-classic%2C%40mail.farm.app.vxclient%2C%40mail.farm.app.fe%2C%40mail.farm.app.delivery%2C%40mail.farm.app.cascade%2C%40mail.farm.app.fe-cg';
$resp = $ua->request($req);

ok( $resp->content eq $tdata, "bigjson" );

ok( PogoTest::stop_mojo(), 'stop_mojo' );

