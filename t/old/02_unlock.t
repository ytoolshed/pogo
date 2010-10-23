#!/usr/local/bin/perl -w
# $Id$
# vim:ft=perl:

# Tests various scenarios which would leave behind locks, or would delete too many locks

use strict;
use Test::More tests => 19;

use Data::Dumper qw(Dumper);
use Time::HiRes qw(sleep);
use Sys::Hostname;
use YAML::Syck qw(LoadFile);
use Log::Log4perl qw(:easy);

#use Log::Log4perl qw(:easy);
#Log::Log4perl->easy_init($DEBUG);

use FindBin qw($Bin);

use lib "$Bin/../lib";
use lib "$Bin/lib";

use Pogo::Server;
use Pogo::Server::Job;
use Pogo::Dispatcher;
use PogoTest;
$Pogo::Server::Job::UPDATE_INTERVAL = 0.1;

ok( Log::Log4perl::init("$Bin/conf/log4perl.conf"), "log4perl" );

ok( PogoTest::start_mojo(), 'start_mojo' );

ok( PogoTest::zookeeper_clear("/pogo") == 0, "zookeeper_clear" );

my $constrfile = "$Bin/conf/constraints.yaml";
my $conffile   = "$Bin/conf/server.conf";
my $constr     = LoadFile($constrfile) || die "cannot load $constrfile";
my $dispconf   = LoadFile($conffile) || die "cannot load $conffile";

mkdir("output_tmp");
$dispconf->{data_dir} = "$Bin/output_tmp";

# FIXME: we need to override Culpa::Client's host so we have repeatability on
# the hostinfo query we're gonna do

ok( my $ns = Pogo::Server->namespace("mail")->init, "Init namespace" );
ok( $ns->set_conf($constr), "Load configuration" );
ok( my $serv = Pogo::Server->instance($dispconf), "Init server" );
ok( ref $serv eq 'Pogo::Server', "Init server ref" );
ok( my $disp = Pogo::Dispatcher->instance($dispconf), "Init dispatcher" );
ok( ref $disp eq 'Pogo::Dispatcher', "Init dispatcher ref" );
ok( my $zkh = Pogo::Server::zkh(), "zookeeper handle" );

# for test code only: start local rpc server without running the dispatcher
$disp->_rpc_server();

sub run_300_job
{
  my ( $fn, $cfn, $state ) = @_;
  my $condvar = AnyEvent->condvar;

  # start a new job
  my $job = Pogo::Server::Job->new(
    { namespace     => "mail",
      user          => "foo",
      password      => PogoTest::cryptpw( $dispconf, "foo" ),
      pkg_passwords => "{}",
      run_as        => "foo",
      invoked_as    => "magic",
      range         => ['@mail.farm.set.mud-prod-300'],
      job_timeout   => 60,
      timeout       => 60,
      command       => 'echo hi',
      foo           => 'bar',
    }
  );
  my $errc = sub { print("error: $@\n"); $condvar->send(0) };
  my $cont = sub { $condvar->send(1) };
  $job->start( $errc, $cont );
  $zkh->delete( "/pogo/taskq/startjob;" . $job->id );
  ok( $condvar->recv(), "startjob " . $job->id );

  is( PogoTest::run_job( $job, $fn, $cfn ), $state, $job->id . " completion state" );

  return $job;
}

my $job1 = run_300_job( sub { return 2; }, undef, "deadlocked" );

is( scalar $ns->global_get_locks, 0, "0 leftover locks from failed job" );

my $failhost  = sub { my ($host) = @_; return $host eq 'web30001.mail.mud.yahoo.com' ? 2 : 0; };
my $stuckhost = sub { my ($host) = @_; return $host eq 'web30005.mail.mud.yahoo.com' ? 2 : 0; };
my $job2 = run_300_job( $failhost, $stuckhost, "running" );
is( scalar $ns->global_get_locks, 2, "num active locks for " . $job2->id );

$job1->halt;

is( scalar $ns->global_get_locks, 2, "num active locks after halt " . $job1->id );

$job2->halt;

is( scalar $ns->global_get_locks, 0, "num active locks after halt " . $job2->id );

# manual dispatcher test
#$disp->run;

ok( PogoTest::stop_mojo(), 'stop_mojo' );

