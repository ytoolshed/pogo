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

use Test::More tests => 11;
use Test::Exception;

use Data::Dumper;
use Carp qw(confess);
use FindBin qw($Bin);
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
  # check that service is alive
  my $t;
  lives_ok { $t = client->ping(); } 'ping send'
    or diag explain $t;
  ok( $t->is_success, 'ping success ' . $t->status_msg )
    or diag explain $t;
  is( $t->record, 0xDEADBEEF, 'ping recv' )
    or diag explain $t;

  # init authstore
  undef $t;
  my $conf = {
    peers    => ["localhost"],
    rpc_port => 7655,
  };
  Pogo::Dispatcher::AuthStore->init($conf);

  # init zookeeper
  my $opts = {
    store         => 'zookeeper',
    store_options => { port => 18121, },
  };
  Pogo::Engine::Store->init($opts);

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


  my $concurrency = 2;
  my $max_observed_concurrency = 0;

  my $job1 = {
    user               => 'test',
    run_as             => 'test',
    password           => encrypt_secret('foo'),
    secrets            => encrypt_secret('bar'),
    client_private_key => encrypt_secret('private_key'),
    pvt_key_passphrase => encrypt_secret('passphrase'),
    command            => 'echo job1',
    target             => [ 'zar[1-4].west.example.com', ],
    namespace          => 'example',
    timeout            => 20,
    job_timeout        => 100,
    concurrent         => $concurrency,
  };


  # kick the job off
  my $resp;
  lives_ok { $resp = client->run(%$job1); } 'run job1'
    or diag explain $@;
  ok( $resp->is_success, "sent run job1" );


  # get the job id from the response
  my $jobid = $resp->record;
  ok( $jobid eq 'p0000000000', "got jobid $jobid" );


  # iterate over the job until it completes
  my @records;
  for ( my $i = 0; $i <= $job1->{job_timeout} * 2; $i++ )
  {

    # get the response from the API
    #diag "checking job status $i...";
    $resp = client->jobstatus($jobid)
      or diag explain $@;
    $resp->is_success
      or diag explain $resp;

    @records = $resp->records;
    my $status = shift @records;
    diag explain "job status is $status";

    if ( $status eq 'deadlocked'
      or $status eq 'halted' ) {
        BAIL_OUT( 'job failed to complete successfully' );

    } elsif ( $status eq 'finished' ) {
        diag "job finished successfully";
        last;
    }

    # @records now contains just the host statuses
    my $running = 0;
    foreach ( @records ) {
        my ( $host, $host_status, $exit ) = @{ $_ };
        $running++ if $host_status eq 'running';
        #diag "$host is $host_status"
    }

    #diag "$running hosts are running";
    ok( 0, "ensure concurrency of $concurrency is not exceeded" ) if $running > $concurrency;
    $max_observed_concurrency = $running
        if $running > $max_observed_concurrency;

    sleep 1;
  }

  ok( ( $max_observed_concurrency >= $concurrency
     or scalar @records < $concurrency ),
      'concurrency reached maximum allowed (or there were less hosts than the max allowed)' );

  ok( $max_observed_concurrency <= $concurrency,
      "concurrency constraint of $concurrency was not exceeded (max was $max_observed_concurrency)" );

};

done_testing();

1;
