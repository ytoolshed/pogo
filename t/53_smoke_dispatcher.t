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

use Test::Exception;
use Test::More tests => 12;

use Carp qw(confess);
use FindBin qw($Bin);
use Log::Log4perl qw(:easy);
use Sys::Hostname qw(hostname);
use YAML::XS qw(LoadFile);
use Pogo::Engine::Store qw(store);

use lib "$Bin/lib";
use PogoTester;
use PogoTesterAlarm;

test_pogo
{
  my $t;

  # root plugin
  lives_ok { $t = store->get("/pogo/root/default"); } 'default plugin'
    or diag explain $t;
  is( $t, 'dummyroot3', 'plugins loaded' )
    or diag explain $t;

  # ping
  undef $t;
  lives_ok { $t = client->ping(); } 'ping send'
    or diag explain $t;
  ok( $t->is_success, 'ping success ' . $t->status_msg )
    or diag explain $t;
  ok( $t->record == 0xDEADBEEF, 'ping recv' )
    or diag explain $t;

  # stats
  undef $t;
  lives_ok { $t = client->stats(); } 'stats send'
    or diag explain $t;
  ok( $t->is_success, 'stats success ' . $t->status_msg )
    or diag explain $t;
  ok( $t->unblessed->{records}->[0]->{hostname} eq hostname(), 'stats' )
    or diag explain $t;

  # badcmd
  undef $t;
  dies_ok { $t = client->weird(); } 'weird send'
    or diag explain $t;
  ok( $@ eq qq{error from pogo server in request 'weird': unknown rpc command 'weird'\n},
    "weird 2" )
    or diag explain $@;

  # loadconf
  undef $t;
  my $conf_to_load = LoadFile("$Bin/conf/example.yaml");
  lives_ok { $t = client->loadconf( 'example', $conf_to_load ) } 'loadconf send'
    or diag explain $t;
  ok( $t->is_success, "loadconf success " . $t->status_msg )
    or diag explain $t;

};

done_testing;

1;

