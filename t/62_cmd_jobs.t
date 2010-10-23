#!/usr/local/bin/perl -w
# $Id$

use strict;
use warnings;

use Test::More tests => 7;

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

  my $cmd = "perl -I$Bin/../lib $pogo --api http://localhost:3000/pogo jobs";
  open3( my $write, \*RFH, \*EFH, $cmd );

  # check the output
  chomp( my $header  = <RFH> );
  chomp( my $body    = <RFH> );

  ok( $header =~ m/^Job ID\s+User\s+Limo Job\s+Command$/,   'header' );

  my ( $jobid, $user, $limo, $command ) = split( /\s+/, $body );
  ok( $jobid eq 'p0000000000',  'jobid' );
  ok( $user eq 'nep',           'user' );
  ok( $limo eq 'ABC123',        'limo' );
  ok( $command eq "'hostname'", 'command' );

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

@@ listjobs.html.eplite
[{"txid":0,"status":"OK","action":"listjobs","rxid":0},[{"connect_timeout":"1","jobid":"p0000000000","user":"nep","limo":"ABC123","cmd":"hostname"}]]
