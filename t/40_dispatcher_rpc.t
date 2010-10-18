#!/usr/local/bin/perl -w

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

use strict;
use warnings;

use Test::More 'no_plan';

use Data::Dumper;
use FindBin qw($Bin);
use JSON;
use Log::Log4perl qw(:easy);
use Net::SSLeay qw();
use YAML::XS qw(LoadFile);

use lib "$Bin/lib/";

use PogoTester;
ok(my $pt = PogoTester->new(), "new pt");

chdir($Bin);

my $js = JSON->new;

# start pogo-dispatcher
ok( $pt->start_zookeeper, 'start zookeeper' );
ok( $pt->start_dispatcher, 'start dispatcher' );

my $conf;
eval { $conf = LoadFile("$Bin/conf/dispatcher.conf"); };
ok( !$@, "loadconf" );

ok($pt->dispatcher_rpc(["ping"])->[0] eq 'pong', 'ping');

# stop
ok( $pt->stop_dispatcher, 'stop dispatcher' );
ok( $pt->stop_zookeeper, 'stop zookeeper' );


1;

