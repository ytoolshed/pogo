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

use Test::More tests => 14;
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


  my $job1 = {
    user               => 'test',
    run_as             => 'test',
    password           => encrypt_secret('foo'),
    secrets            => encrypt_secret('bar'),
    client_private_key => encrypt_secret('private_key'),
    pvt_key_passphrase => encrypt_secret('passphrase'),
    command            => 'echo job1',

    target             => [ # first slot, 1 at a time:
                            'foo20.east.example.com',
                            'foo21.east.example.com',
                            'foo22.east.example.com',
                            'foo23.east.example.com',
                            # second slot:
                             'bar1.west.example.com',
                            # third slot:
                             'zar1.west.example.com', ],

    namespace          => 'example',
    timeout            => 20,
    job_timeout        => 120,
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
  my %checked_hosts;
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


    # put the statuses into a hash so we can look them up by host
    my %status_by_host = map { $_->[0] => { status => $_->[1], 'exit' => $_->[2] }  } @records;

    diag ( map { $_ . ' ' . $status_by_host{$_}->{status} . "\n"  } keys %status_by_host );



    # check (once) that zar isn't running unless bar is finished
    if ( ! $checked_hosts{'zar1.west.example.com'}
     and ( $status_by_host{'zar1.west.example.com'}->{status} eq 'ready'
        or $status_by_host{'zar1.west.example.com'}->{status} eq 'running' ) ) {

        is( $status_by_host{'bar1.west.example.com'}->{status}, 'finished',
            'check that "tail" hosts are running last' );
        $checked_hosts{'zar1.west.example.com'} = 1;
    }


    # check (once) that bar isn't running unless foos are done
    if ( ! $checked_hosts{'bar1.west.example.com'}
     and ( $status_by_host{'bar1.west.example.com'}->{status} eq 'ready'
        or $status_by_host{'bar1.west.example.com'}->{status} eq 'running' ) ) {

        is( $status_by_host{'foo20.east.example.com'}->{status}, 'finished', 'check that foo20 finished before bar1 started' );
        is( $status_by_host{'foo21.east.example.com'}->{status}, 'finished', 'check that foo21 finished before bar1 started' );
        is( $status_by_host{'foo22.east.example.com'}->{status}, 'finished', 'check that foo22 finished before bar1 started' );
        is( $status_by_host{'foo23.east.example.com'}->{status}, 'finished', 'check that foo23 finished before bar1 started' );

        $checked_hosts{'bar1.west.example.com'} = 1;
    }

    # check for "final" statuses
    if ( $status eq 'deadlocked'
      or $status eq 'halted' ) {
        BAIL_OUT( 'job failed to complete successfully' );

    } elsif ( $status eq 'finished' ) {
        diag "job finished successfully";
        last;
    }

    sleep 1;
  }
};

done_testing();

1;
