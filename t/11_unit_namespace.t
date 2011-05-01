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
use strict;
use warnings;

use Test::Exception;
use Test::More tests => 19;

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

use Pogo::Engine;
use Pogo::Engine::Namespace;
use Pogo::Engine::Job;

use Test::MockObject;
use File::Basename;

use Pogo::Engine::Store qw(store);

my $conf = LoadFile("$Bin/conf/example.yaml");

# Log::Log4perl->easy_init({ level => $DEBUG, layout => "%F{1}-%L: %m%n" });

my $store = PogoMockStore->new();
$store->create( '/foo/bar/baz' );

my $str = $store->_dump();
is($str, <<EOT, "PogoMockStore simple");
/
/foo
/foo/bar
/foo/bar/baz
EOT

$store = PogoMockStore->new();

is($store->set("/pogo/job/p000000", undef), undef, "set without create");
is($store->get("/pogo/job/p000000", undef), undef, "get without create");
ok($store->create("/pogo/job/p000000"), "create deep path");
ok($store->set("/pogo/job/p000000", 2), "set after create");
is($store->get("/pogo/job/p000000"), 2, "get after set");

ok($store->delete_r("/pogo/job/p000000"), "delete base node");
$str = $store->_dump();
is($str, <<EOT, "PogoMockStore simple");
/
/pogo
/pogo/job
EOT

ok($store->delete_r("/pogo"), "delete top-level entry");
$str = $store->_dump();
is($str, <<EOT, "PogoMockStore empty");
/
EOT

ok($store->create("/pogo/job/p000000/meta/target"), "create deep dir");
ok($store->set("/pogo/job/p000000/meta/target", ["blah"]), "set array");
like($store->get("/pogo/job/p000000/meta/target"), qr/^ARRAY/, "get array");

my @children = $store->get_children("/pogo/job");

is("@children", "p000000", "get_children");

ok($store->create_sequence("/pogo/job/p000000/meta/target/p"), "create seq");
ok($store->create_sequence("/pogo/job/p000000/meta/target/p"), "create seq");
ok($store->create_sequence("/pogo/job/p000000/meta/target/p"), "create seq");

@children = $store->get_children("/pogo/job/p000000/meta/target");

is("@children", "p000001 p000002 p000003", "get_children");

$store->delete_r("/pogo");

ok(1, "at the end");

1;
