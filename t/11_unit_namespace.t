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
use JSON;
use Log::Log4perl qw(:easy);
use Net::SSLeay qw();
use Sys::Hostname qw(hostname);
use YAML::XS qw(Load LoadFile);

use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoTesterAlarm;

chdir($Bin);

use Pogo::Engine::Namespace;

use Test::MockObject;
my $conf = LoadFile("$Bin/conf/example.yaml");

my $store = Test::MockObject->new();
for my $method (qw(store create exists delete_r))
{
  $store->mock( $method => sub { return 1; } );
}
$store->mock( "set" => sub { $_[0]->{ $_[1] } = $_[2] } );
$store->mock( "get" => sub { return $_[0]->{ $_[1] } } );

my $slot = Test::MockObject->new();

my $ns = Pogo::Engine::Namespace->new(
  store    => $store,
  get_slot => $slot,
  nsname   => "wonk",
);

$ns->set_conf($conf);

ok( 1, "at the end" );
1;
