#!/usr/local/bin/perl -w
# $Id$

use strict;
use warnings;

use Test::More tests => 13;

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
# force tz to PST8PDT
$ENV{TZ} = 'US/Pacific';

# set up mojolicious
app->log->level('error');

any '/pogo' => 'joblog';

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

  my $cmd = "perl -I$Bin/../lib $pogo --api http://localhost:3000/pogo log 0";
  open3( my $write, \*RFH, \*EFH, $cmd );

  # check the output
  my @res;
  while ( <RFH> )
  {
    chomp();
    push( @res, $_ );
  }

  ok( scalar( @res ) == 10, 'records' );
  ok( $res[0] eq "Oct 29 13:44:07 UTC-0700 job => job created", 'record 1');
  ok( $res[1] eq "Oct 29 13:44:08 UTC-0700 host/mix619501.mail.ac4.yahoo.com => mix619501.mail.ac4.yahoo.com unreachable", 'record 2' );
  ok( $res[2] eq "Oct 29 13:44:08 UTC-0700 lock/mix619501.mail.ac4.yahoo.com => mix619501.mail.ac4.yahoo.com assumed unreachable; locking", 'record 3' );
  ok( $res[3] eq "Oct 29 13:44:08 UTC-0700 host/mix619502.mail.ac4.yahoo.com => mix619502.mail.ac4.yahoo.com unreachable", 'record 4' );
  ok( $res[4] eq "Oct 29 13:44:08 UTC-0700 lock/mix619502.mail.ac4.yahoo.com => mix619502.mail.ac4.yahoo.com assumed unreachable; locking", 'record 5' );
  ok( $res[5] eq "Oct 29 13:44:08 UTC-0700 host/vxs619501.mail.ac4.yahoo.com => vxs619501.mail.ac4.yahoo.com unreachable", 'record 6' );
  ok( $res[6] eq "Oct 29 13:44:08 UTC-0700 lock/vxs619501.mail.ac4.yahoo.com => vxs619501.mail.ac4.yahoo.com assumed unreachable; locking", 'record 7' );
  ok( $res[7] eq "Oct 29 13:44:08 UTC-0700 host/web619501.mail.ac4.yahoo.com => web619501.mail.ac4.yahoo.com state=unreachable", 'record 8' );
  ok( $res[8] eq "Oct 29 13:44:08 UTC-0700 job => hosts contacted; running job", 'record 9' );
  ok( $res[9] eq "Oct 29 13:44:08 UTC-0700 lock/web619501.mail.ac4.yahoo.com => web619501.mail.ac4.yahoo.com assumed unreachable; locking", 'record 10' );

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

@@ joblog.html.eplite
[{"txid":0,"status":"OK","action":"joblog","rxid":0},[[3,1256849048.09235,"hoststate",{"state":"unreachable","host":"mix619502.mail.ac4.yahoo.com"},"mix619502.mail.ac4.yahoo.com unreachable"],[2,1256849048.08903,"lock",{"host":"mix619501.mail.ac4.yahoo.com"},"mix619501.mail.ac4.yahoo.com assumed unreachable; locking"],[1,1256849048.08773,"hoststate",{"state":"unreachable","host":"mix619501.mail.ac4.yahoo.com"},"mix619501.mail.ac4.yahoo.com unreachable"],[0,1256849047.09175,"jobstate",{"range":"@mail.farm.set.ac4-qa-6195","state":"gathering"},"job created"],[8,1256849048.10552,"jobstate",{"state":"running"},"hosts contacted; running job"],[9,1256849048.11118,"lock",{"host":"web619501.mail.ac4.yahoo.com"},"web619501.mail.ac4.yahoo.com assumed unreachable; locking"],[6,1256849048.10114,"lock",{"host":"vxs619501.mail.ac4.yahoo.com"},"vxs619501.mail.ac4.yahoo.com assumed unreachable; locking"],[7,1256849048.10504,"hoststate",{"state":"unreachable","host":"web619501.mail.ac4.yahoo.com"},"web619501.mail.ac4.yahoo.com state=unreachable"],[4,1256849048.09552,"lock",{"host":"mix619502.mail.ac4.yahoo.com"},"mix619502.mail.ac4.yahoo.com assumed unreachable; locking"],[5,1256849048.0995,"hoststate",{"state":"unreachable","host":"vxs619501.mail.ac4.yahoo.com"},"vxs619501.mail.ac4.yahoo.com unreachable"]]]
