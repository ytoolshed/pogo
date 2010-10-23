#!/usr/local/bin/perl -w
# $Id$
# vim:ft=perl:

# Tests various scenarios which would leave behind locks, or would delete too many locks

use strict;
use Test::More tests => 13;

use Data::Dumper qw(Dumper);
use Time::HiRes qw(sleep);
use Sys::Hostname;
use YAML::Syck qw(LoadFile);

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
ok( PogoTest::start_mojo(),                  'start_mojo' );
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

my $condvar = AnyEvent->condvar;

my ( $fn, $cfn, $state ) = @_;

# start a new job
my $job = Pogo::Server::Job->new(
  { namespace     => "mail",
    user          => "foo",
    password      => PogoTest::cryptpw( $dispconf, "foo" ),
    pkg_passwords => "{}",
    run_as        => "foo",
    invoked_as    => "magic",
    range         => ['@mail.farm.set.ac4-qa-6195'],
    timeout       => 3,
    job_timeout   => 3,
    command       => 'echo hi',
    foo           => 'bar',
  }
);
my $errc = sub { print("error: $@\n"); $condvar->send(0) };
my $cont = sub { $condvar->send(1) };
$job->start( $errc, $cont );
$zkh->delete( "/pogo/taskq/startjob;" . $job->id );
ok( $condvar->recv(), "startjob " . $job->id );

$condvar = AnyEvent->condvar;
my $poll_timer;
my $poll = sub {
  $job = Pogo::Server->job( $job->id );
  if ( !$job->is_running )
  {
    $condvar->send( $job->state );
    undef $poll_timer;
  }
};

$poll_timer = AnyEvent->timer(
  after    => 0.1,
  interval => 0.1,
  cb       => $poll,
);

my $t0 = time;
is( $condvar->recv(), "halted", "timed out job state" );
my $t1 = time;
ok( $t1 - $t0 <= 4, "timed out within 3 seconds" );

ok( PogoTest::stop_mojo(), 'stop_mojo' );

