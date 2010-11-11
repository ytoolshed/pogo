#!/usr/bin/env perl -w
# $Id$

use strict;
use warnings;

use Test::More tests => 3;

use Data::Dumper;
use Mojolicious::Lite;
use Log::Log4perl qw(:easy);
use IPC::Open3;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use lib "$Bin/../../server/lib/";
my $pogo = "$Bin/../bin/pogo";

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

  my $cmd = "perl -I$Bin/../lib $pogo --api http://localhost:3000/pogo ping";
  print "cmd=$cmd\n";
  open3( my $write, \*RFH, \*EFH, $cmd );

  # check the output
  my $res;
  eval { $res = <RFH>; };
  ok( $res =~ m/^OK http:\/\/localhost:3000\/pogo \d+ms$/, 'pong' );
  print Dumper $res;

  # check for anything on STDERR
  my $err;
  while ( <EFH> )
  {
    $err .= $_;
  }
  ok( ! $err, 'stderr' );

  print "Killing server\n";
  kill 9, $pid;
}
__DATA__

@@ pong.html.eplite
[{"txid":0,"status":"OK","action":"ping","rxid":0},["pong"]]
