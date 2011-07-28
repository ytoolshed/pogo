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
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";

use PogoTester;
use PogoTesterAlarm;

test_pogo
{
  my $t;

  # ping
  undef $t;
  lives_ok { $t = client->ping(); } 'ping send'
    or diag explain $t;
  ok( $t->is_success, 'ping success ' . $t->status_msg )
    or diag explain $t;
  ok( $t->record == 0xDEADBEEF, 'ping recv' )
    or diag explain $t;

  # make sure we got the right UA plugin
  is(
    ref( client->ua() ),
    'Pogo::Plugin::UserAgent::TestAgent',
    'loaded correct UA Plugin, Pogo::Plugin::UserAgent::TestAgent'
  );
};

done_testing;

1;

