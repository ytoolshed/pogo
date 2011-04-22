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
use Test::More tests => 1;

use Carp qw(confess);
use Data::Dumper;
use FindBin qw($Bin);
use Log::Log4perl qw(:easy);
use Net::SSLeay qw();
use Sys::Hostname qw(hostname);
use YAML::XS qw(Load LoadFile);
use JSON qw(encode_json);

use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoTesterAlarm;
use PogoMockStore;

chdir($Bin);

use Pogo::Engine::Namespace;

use Test::MockObject;
use File::Basename;

my $conf = LoadFile("$Bin/conf/example.yaml");

# Log::Log4perl->easy_init($DEBUG);

my $store = PogoMockStore->new();
my $slot  = Test::MockObject->new();

my $ns = Pogo::Engine::Namespace->new(
  store    => $store,
  get_slot => $slot,
  nsname   => "wonk",
);

$ns->set_conf($conf);
my $c = $ns->get_conf($conf);

use Data::Dumper;
# print Dumper( $c );

ok( 1, "at the end" );

1;
