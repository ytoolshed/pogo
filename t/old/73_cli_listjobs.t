#!/usr/bin/env perl -w
# $Id$

use strict;
use warnings;

use Test::More tests => 5;

use Data::Dumper;
use Mojolicious::Lite;
use Log::Log4perl qw(:easy);

use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/../../server/lib/";

Log::Log4perl::init( "$Bin/t.log4perl" );

use_ok('Pogo::Client');

# set up mojolicious
app->log->level('error');

any '/pogo' => 'listjobs';

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
    my $resp  = $pc->listjobs;
    my @rec   = $resp->records;

    ok( $resp->is_success, 'is_success' );
    ok( $rec[0]->{jobid} eq 'p0000000000',  'jobid = p0000000000' );
    ok( $rec[0]->{connect_timeout} eq '1',  'connect_timeout = 1' );
    ok( $rec[0]->{foo} eq 'bar',            'foo = bar' );
  };
  if ( $@ )
  {
    print "ERROR: $@\n";
  }

  print "Killing server\n";
  kill 9, $pid;
}
__DATA__

@@ listjobs.html.eplite
[{"txid":0,"status":"OK","action":"listjobs","rxid":0},[{"connect_timeout":"1","jobid":"p0000000000","foo":"bar"}]]
