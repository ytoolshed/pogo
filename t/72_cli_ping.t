#!/usr/bin/env perl -w
# $Id$

use strict;
use warnings;

use Test::More tests => 3;

use Data::Dumper;
use Mojolicious::Lite;
use Log::Log4perl qw(:easy);

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use lib "$Bin/../../server/lib/";

Log::Log4perl::init( "$Bin/t.log4perl" );

use_ok('Pogo::Client');

# set up mojolicious
app->log->level('error');

any '/pogo' => 'pong';

# start mojolicious
my $pid = fork();
if ( $pid == 0 )
{
  shagadelic('daemon');
}
else
{
  print "Waiting for server to start\n";
  sleep 1;

  eval {
    my $pc    = Pogo::Client->new( 'http://localhost:3000/pogo' );
    my $resp  = $pc->ping;
    my @pong  = $resp->records;

    ok( $resp->is_success, 'is_success' );
    ok( $pong[0] eq 'pong', 'pong' );

  };
  if ( $@ )
  {
    print "ERROR: $@\n";
  }

  print "Killing server\n";
  kill 9, $pid;
}
__DATA__

@@ pong.html.eplite
[{"txid":0,"status":"OK","action":"ping","rxid":0},["pong"]]
