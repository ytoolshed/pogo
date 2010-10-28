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

use common::sense;

use Test::More 'no_plan';

use Data::Dumper;
use FindBin qw($Bin);
use JSON;
use Log::Log4perl qw(:easy);
use Net::SSLeay qw();
use YAML::XS qw(LoadFile);
use Sys::Hostname qw(hostname);

use lib "$Bin/lib/";

use PogoTester qw(derp);
ok( my $pt = PogoTester->new(), "new pt" );

chdir($Bin);

ok( Log::Log4perl::init("$Bin/conf/log4perl.conf"), "log4perl" );

my $js = JSON->new;
my $t;

# start pogo-dispatcher
ok( $pt->start_zookeeper,  'start zookeeper' );
ok( $pt->start_dispatcher, 'start dispatcher' );

my $conf;
eval { $conf = LoadFile("$Bin/conf/dispatcher.conf"); };
ok( !$@, "loadconf" );

# ping
$t = $pt->dispatcher_rpc( ["ping"] );
ok( $t->[1]->[0] == 0xDEADBEEF, 'ping' )
  or print Dumper $t;

# stats
$t = $pt->dispatcher_rpc( ["stats"] );
ok( $t->[1]->[0]->{hostname} eq hostname(), 'stats' )
  or print Dumper $t;

# badcmd
$t = $pt->dispatcher_rpc( ["weird"] );
ok( $t->[0]->{status} eq 'ERROR', 'weird' )
  or print Dumper $t;
ok( $t->[0]->{errmsg} eq qq/unknown rpc command 'weird'/, 'weird 2' );

# loadconf
my $conf_to_load = LoadFile("$Bin/conf/constraints.test.yaml");
$t = $pt->dispatcher_rpc( ["loadconf", $conf_to_load] )
  or print Dumper $t;


# stop
ok( $pt->stop_dispatcher, 'stop dispatcher' );
ok( $pt->stop_zookeeper,  'stop zookeeper' );

1;

