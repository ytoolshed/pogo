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

use common::sense;

use Test::More tests => 9;
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

  undef $t;
  my $host   = 'foo11.west.example.com';
  my $ns     = 'example';
  my $record = [];
  lives_ok { $t = client->hostinfo( $host, $ns ); } "hostinfo $ns/$host"
    or diag explain $t;
  ok( $t->is_success, "hostinfo $ns/$host success" )
    or diag explain $t;
  is( $t->records, $record, 'stats' )
    or diag explain $t;
};

done_testing();

1;
