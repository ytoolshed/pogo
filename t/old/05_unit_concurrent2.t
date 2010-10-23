#!/usr/local/bin/perl -w
# $Id: 05_unit_concurrent2.t 283310 2010-09-05 16:41:19Z nharteau $
# vim:ft=perl:

# Test scenario #2: use farm 6195, which has one host of each type
# run hosts 100% concurrent

# Tests basic functionality and logging

use strict;
use Test::More tests => 41;

use Data::Dumper qw(Dumper);
use Time::HiRes qw(sleep);
use Sys::Hostname;
use YAML::Syck qw(LoadFile);
use JSON;
use Log::Log4perl qw(:easy);

use FindBin qw($Bin);

use lib "$Bin/../lib";
use lib "$Bin/lib";

use Pogo::Server;
use Pogo::Server::Job;
use Pogo::Dispatcher;
use PogoTest;
$Pogo::Server::Job::UPDATE_INTERVAL = 1e-3;

ok( Log::Log4perl::init("$Bin/conf/log4perl.conf"), "log4perl" );
ok( PogoTest::zookeeper_clear("/pogo") == 0,             "zookeeper_clear" );

ok( PogoTest::start_mojo(), 'start_mojo' );

SKIP:
{
  skip "not yet working", 37;

  my $constrfile = "$Bin/conf/constraints.yaml";
  my $conffile   = "$Bin/conf/server.conf";
  my $constr     = LoadFile($constrfile) || die "cannot load $constrfile";
  my $dispconf   = LoadFile($conffile) || die "cannot load $conffile";

  mkdir("output_tmp");
  $dispconf->{data_dir} = "$Bin/output_tmp";

  ok( my $ns = Pogo::Server->namespace("mail")->init, "Init namespace" );
  ok( $ns->set_conf($constr), "Load configuration" );
  ok( my $serv = Pogo::Server->instance($dispconf), "Init server" );
  ok( ref $serv eq 'Pogo::Server', "Init server ref" );
  ok( my $disp = Pogo::Dispatcher->instance($dispconf), "Init dispatcher" );
  ok( ref $disp eq 'Pogo::Dispatcher', "Init dispatcher ref" );
  ok( my $zkh = Pogo::Server::zkh(), "zookeeper handle" );

  is( scalar Pogo::Server->listjobs(), 0, "empty job list" );

  my $condvar = AnyEvent->condvar;

  # start a new job
  my $job = Pogo::Server::Job->new(
    { namespace     => "mail",
      user          => "foo",
      password      => PogoTest::cryptpw( $dispconf, "foo" ),
      pkg_passwords => "{}",
      run_as        => "foo",
      invoked_as    => "magic",
      range         => ['@mail.farm.set.ac4-qa-6195'],
      timeout       => 60,
      job_timeout   => 60,
      command       => 'echo hi',
      concurrent    => 1,
      foo           => 'bar',
    }
  );

  is( $job->id, "p0000000000", "initial jobid" );

  ok( $zkh->exists("/pogo/taskq/startjob;p0000000000"), "startjob taskq entry" );

  $zkh->delete("/pogo/taskq/startjob;p0000000000");
  my $errc = sub { print("error: $@\n"); $condvar->send(0) };
  my $cont = sub { $condvar->send(1) };
  $job->start( $errc, $cont );
  ok( $condvar->recv(), "startjob" );

  # we should get one mix01, one mix02, and one vxs
  is( scalar $zkh->get_children("/pogo/taskq"), 1, "runhost count" );

  is( PogoTest::run_job( $job, sub { my ($hostname) = @_; return 0; } ),
    "finished", "job completion" );

  my @log = $job->read_log();
  is( scalar @log,                 34,          "job log: entry count" );
  is( $log[9]->[2],                "hoststate", "job log: entry format" );
  is( $log[21]->[3]->{exitstatus}, 0,           "jobstatus: exit status" );

  @log = $job->read_log(5);
  is( scalar @log, 24, "offset job log: entry count" );
  @log = $job->read_log( 0, 3 );
  is( scalar @log, 3, "limited job log: entry count" );

  my @joblist = Pogo::Server->listjobs;
  is( scalar @joblist,        1,             "job list" );
  is( $joblist[0]->{'jobid'}, "p0000000000", "job id format" );
  cmp_ok( $joblist[0]->{'start_time'}, '>', 1200000000, "job start time" );

  @joblist = Pogo::Server->listjobs( { foo => 'twee' } );
  is( scalar @joblist, 0, "filtered job list 1" );
  @joblist = Pogo::Server->listjobs( { foo => 'bar' } );
  is( scalar @joblist, 1, "filtered job list 2" );

  is( Pogo::Server->lastjob( { foo => 'bar' } ), "p0000000000", "lastjob" );

  is( $job->state, 'finished', "jobstatus" );
  my @hoststatus = map { [ $_->name, $_->state ] } $job->hosts;
  @hoststatus = sort { $a->[0] cmp $b->[0] } @hoststatus;
  is( $hoststatus[0]->[0], 'mix619501.mail.ac4.yahoo.com', "jobstatus: host name" );
  is( $hoststatus[0]->[1], 'finished', "jobstatus: host status" );

  my ( $idx, $snap ) = $job->snapshot;
  is( $idx,      29, "snapshot index" );
  is( ref $snap, '', "snapshot type" );
  my $decode_snap = from_json($snap);
  is( $decode_snap->{job}->{state},                            "finished", "snapshot job state" );
  is( $decode_snap->{"web619501.mail.ac4.yahoo.com"}->{state}, "finished", "snapshot host state" );
  is( $decode_snap->{"web619501.mail.ac4.yahoo.com"}->{runs}->[0]->{'x'},
    0, "snapshot host exitcode" );
  my ( $idx2, $snap2 ) = $job->snapshot;
  is( $idx2,  29,    "cached snapshot index" );
  is( $snap2, $snap, "cached snapshot data" );

  my ( $idx3, $snap3 ) = $job->snapshot(40);
  is( $idx3, 29, "partial snapshot index" );
  isnt( $snap3, $snap, "partial snapshot data" );

  my ( $idx4, $snap4 ) = $job->snapshot(45);
  is( $snap4, "{}", "empty snapshot data" );

}    #END SKIP BLOCK

# be last
ok( PogoTest::stop_mojo(), 'stop_mojo' );

