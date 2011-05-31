#!/usr/bin/env perl -w

# Copyright (c) 2010-2011 Yahoo! Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use 5.008;
use common::sense;

use Test::More tests => 28;
use Test::Exception;

use Data::Dumper;
use Carp qw(confess);
use FindBin qw($Bin);
use Sys::Hostname qw(hostname);
use Time::HiRes qw(sleep);
use YAML::XS qw(LoadFile);

use Pogo::Engine::Job;
use Pogo::Engine::Store qw(store);
use Pogo::Engine;
use Pogo::Dispatcher::AuthStore;

use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoTester;
use PogoTesterAlarm;

test_pogo
{
  my $t;
  lives_ok { $t = client->ping(); } 'ping send'
    or diag explain $t;
  ok( $t->is_success, 'ping success ' . $t->status_msg )
    or diag explain $t;
  is( $t->record, 0xDEADBEEF, 'ping recv' )
    or diag explain $t;

  # default_transform
  undef $t;
  my $conf = {
    peers => [ "localhost" ],
    rpc_port => 7655,
  };
  Pogo::Dispatcher::AuthStore->init($conf);
  
  my $opts = {
    store => 'zookeeper',
    store_options => { port => 18121,},
  };
  Pogo::Engine::Store->init($opts);

  my $opts = {
    user        => 'test',
    run_as      => 'test',
    password    => encrypt_secret('foo'),
    secrets     => encrypt_secret('bar'),
    command     => 'echo jobdefault',
    target      => [ 'foo.example.com', ],
    namespace   => 'example',
    timeout     => 1,
    job_timeout => 1,
    concurrent  => 1,
  };
  my $job;
  $job = Pogo::Engine::Job->new($opts);
  lives_ok{ $t = $job->command_root_transform(); } 'load default transform'
    or diag explain $t;
  is( $t, "dummyroot3 \${rootname} --cmd \${command}", 'default transform loaded' )
    or diag explain $t;

  # loadconf
  undef $t;
  my $conf_to_load;
  lives_ok { $conf_to_load = LoadFile("$Bin/conf/example.yaml") } 'load yaml'
    or diag explain $t;
  lives_ok { $t = client->loadconf( 'example', $conf_to_load ) } 'loadconf send'
    or diag explain $t;
  ok( $t->is_success, "loadconf send " . $t->status_msg )
    or diag explain $t;

  sleep 1;

  # namespace transform
  undef $t;
  lives_ok{ $t = $job->command_root_transform(); } 'load namespace transform'
    or diag explain $t;
  is( $t, "dummyroot2 \${rootname} --cmd \${command}", 'namespace transform loaded' )
    or diag explain $t;

  # job transform
  undef $t;
  my $opts = {
    user        => 'test',
    run_as      => 'test',
    password    => encrypt_secret('foo'),
    secrets     => encrypt_secret('bar'),
    command     => 'echo jobclient',
    target      => [ 'foo.example.com', ],
    namespace   => 'example',
    root_type   => 'dummyroot1',
    timeout     => 1,
    job_timeout => 1,
    concurrent  => 1,
  };
  my $job;
  $job = Pogo::Engine::Job->new($opts);
  lives_ok{ $t = $job->command_root_transform(); } 'load client transform'
    or diag explain $t;
  is( $t, "dummyroot1 \${rootname} --cmd \${command}", 'client transform loaded' )
    or diag explain $t;

  undef $t;
  lives_ok { $t = client->stats(); } 'stats send'
    or diag explain $t;
  ok( $t->is_success, 'stats success' )
    or diag explain $t;
  is( $t->unblessed->[1]->[0]->{hostname}, hostname(), 'stats' )
    or diag explain $t;

  foreach my $dispatcher ( $t->records )
  {
    ok( exists $dispatcher->{workers_idle}, "exists workers_idle" )
      or diag explain $dispatcher;
    ok( exists $dispatcher->{workers_busy}, "exists workers_busy" )
      or diag explain $dispatcher;
    is( scalar @{$dispatcher->{workers_idle}}, 1, "one workers_idle" )
      or diag explain $dispatcher;
    is( scalar @{$dispatcher->{workers_busy}}, 0, "zero workers_busy" )
      or diag explain $dispatcher;
  }

  my $job0 = {
    user        => 'test',
    run_as      => 'test',
    #password    => encrypt_secret('foo'),
    secrets     => encrypt_secret('bar'),
    #client_private_key => encrypt_secret('private_key'),
    pvt_key_passphrase  => encrypt_secret('passphrase'),
    command     => 'echo job1',
    target      => [ 'foo[1-10].example.com', ],
    namespace   => 'example',
    timeout     => 5,
    job_timeout => 5,
    concurrent  => 1,
  };

  my $resp0;
  dies_ok { $resp0 = client->run(%$job0); } 'run job0'
    or diag explain $@;

  my $job1 = {
    user        => 'test',
    run_as      => 'test',
    password    => encrypt_secret('foo'),
    secrets     => encrypt_secret('bar'),
    client_private_key => encrypt_secret('private_key'),
    pvt_key_passphrase  => encrypt_secret('passphrase'),
    command     => 'echo job1',
    target      => [ 'foo[1-10].example.com', ],
    namespace   => 'example',
    timeout     => 5,
    job_timeout => 5,
    concurrent  => 1,
  };

  my $resp;
  lives_ok { $resp = client->run(%$job1); } 'run job1'
    or diag explain $@;
  ok( $resp->is_success, "sent run job1" );

  my $jobid = $resp->record;

  ok( $jobid eq 'p0000000002', "got jobid" );

  sleep $job1->{job_timeout};    # job should timeout

  my @records;
  for (my $i = 0; $i <= $job1->{job_timeout} * 2; $i++)
  {
    $resp = client->jobstatus($jobid)
      or diag explain $@;
    $resp->is_success
      or diag explain $resp;
    @records = $resp->records;

    last if $records[0] eq 'halted';
    sleep 1;
  }

  is( $records[0], 'halted', "job $jobid halted" )
    or diag explain \@records;

  # test jobretry
  dies_ok { $resp = client->jobretry( $jobid, ['foo11.example.com'] ) }
  "job retry for foo11.example.com"
    or diag explain $@;

  ok( $@ =~ m/expired/, "expiry message for foo11.example.com" )
    or diag explain $resp;

  dies_ok { $resp = client->jobretry( $jobid, ['foo9.example.com'] ) } "job retry for foo9.example.com"
    or diag explain $@;

  ok( $@ =~ m/expired/, "expiry message for foo9.example.com" )
    or diag explain $resp;

  # TODO: test successful retry, retry while job still running.

};

done_testing();

1;
