#!/usr/bin/env perl -w

# Copyright (c) 2010, Yahoo! Inc. All rights reserved.
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

use Test::More tests => 8;
use Test::Exception;

use Data::Dumper;
use Carp qw(confess);
use FindBin qw($Bin);
use Sys::Hostname qw(hostname);
use Time::HiRes qw(sleep);
use YAML::XS qw(LoadFile);

use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoTester;
use Pogo::Engine;
use Pogo::Engine::Job;
use Pogo::Engine::Store qw(store);
use Pogo::Dispatcher::AuthStore;

$SIG{ALRM} = sub { confess; };
alarm(60);

test_pogo
{
  my $t;
  $t = dispatcher_rpc( ["ping"] );
  is( $t->[1]->[0], 0xDEADBEEF, 'ping' )
    or diag explain $t;

  # loadconf
  my $conf_to_load;
  lives_ok { $conf_to_load = LoadFile("$Bin/conf/example.yaml") };
  $t = dispatcher_rpc( [ 'loadconf', 'example', $conf_to_load ] );
  is( $t->[0]->{status}, 'OK', 'loadconf rpc OK' )
    or diag explain $t;

  $t = dispatcher_rpc( ["stats"] );
  is( $t->[1]->[0]->{hostname}, hostname(), 'stats' )
    or diag explain $t;

  foreach my $dispatcher ( @{ $t->[1] } )
  {
    ok( exists $dispatcher->{workers_idle}, "exists workers_idle" )
      or diag explain $dispatcher;
    ok( exists $dispatcher->{workers_busy}, "exists workers_busy" )
      or diag explain $dispatcher;
    ok( $dispatcher->{workers_idle} == 1, "one workers_idle" )
      or diag explain $dispatcher;
    ok( $dispatcher->{workers_busy} == 0, "zero workers_busy" )
      or diag explain $dispatcher;
  }

};

done_testing();

1;
