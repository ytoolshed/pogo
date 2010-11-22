#!/usr/bin/env perl -w
# $Id$;

use strict;
use warnings;

use Test::More tests => 11;

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

  eval {
    my $pc    = Pogo::Client->new( 'http://localhost:3000/pogo' );
    my $resp  = $pc->joblog( 'p0000000000', 0 );
    my @rec   = $resp->records;

    ok( $resp->is_success,  'is_success' );
    ok( scalar(@rec) == 10, 'record count' );

    # check out the first record
    ok( $rec[0][0] eq '3',                                        'record[0] idx' );
    ok( $rec[0][1] eq '1256849048.09235',                         'record[0] ts' );
    ok( $rec[0][2] eq 'hoststate',                                'record[0] state' );
    ok( $rec[0][3]->{'host'} eq 'mix619502.mail.ac4.yahoo.com',   'record[0] hostname' );
    ok( $rec[0][3]->{'state'} eq 'unreachable',                   'record[0] hoststate' );
    ok( $rec[0][4] eq 'mix619502.mail.ac4.yahoo.com unreachable', 'record[0] msg' );

    # try parsing the results for job info
    my $status = { job => {} };
    foreach my $record ( sort { $a->[0] <=> $b->[0] } @rec ) {
      my ( $logidx, $ts, $action, $args, $msg ) = @$record;
      if ( $action eq 'jobstate' )
      {
        foreach my $k ( keys %$args )
        {
          $status->{job}->{$k} = $args->{$k};
        }
      }
    }
    ok( $status->{job}->{'range'} eq '@mail.farm.set.ac4-qa-6195',  'job range' );
    ok( $status->{job}->{'state'} eq 'running',                     'job state' );
  };
  if ( $@ )
  {
    print "ERROR: $@\n";
  }

  print "Killing server\n";
  kill 9, $pid;
}
__DATA__

@@ joblog.html.eplite
[{"txid":0,"status":"OK","action":"joblog","rxid":0},[[3,1256849048.09235,"hoststate",{"state":"unreachable","host":"mix619502.mail.ac4.yahoo.com"},"mix619502.mail.ac4.yahoo.com unreachable"],[2,1256849048.08903,"lock",{"host":"mix619501.mail.ac4.yahoo.com"},"mix619501.mail.ac4.yahoo.com assumed unreachable; locking"],[1,1256849048.08773,"hoststate",{"state":"unreachable","host":"mix619501.mail.ac4.yahoo.com"},"mix619501.mail.ac4.yahoo.com unreachable"],[0,1256849047.09175,"jobstate",{"range":"@mail.farm.set.ac4-qa-6195","state":"gathering"},"job created"],[8,1256849048.10552,"jobstate",{"state":"running"},"hosts contacted; running job"],[9,1256849048.11118,"lock",{"host":"web619501.mail.ac4.yahoo.com"},"web619501.mail.ac4.yahoo.com assumed unreachable; locking"],[6,1256849048.10114,"lock",{"host":"vxs619501.mail.ac4.yahoo.com"},"vxs619501.mail.ac4.yahoo.com assumed unreachable; locking"],[7,1256849048.10504,"hoststate",{"state":"unreachable","host":"web619501.mail.ac4.yahoo.com"},"web619501.mail.ac4.yahoo.com state=unreachable"],[4,1256849048.09552,"lock",{"host":"mix619502.mail.ac4.yahoo.com"},"mix619502.mail.ac4.yahoo.com assumed unreachable; locking"],[5,1256849048.0995,"hoststate",{"state":"unreachable","host":"vxs619501.mail.ac4.yahoo.com"},"vxs619501.mail.ac4.yahoo.com unreachable"]]]
