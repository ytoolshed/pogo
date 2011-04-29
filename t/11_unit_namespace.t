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

use Pogo::Engine;
use Pogo::Engine::Namespace;
use Pogo::Engine::Job;

use Test::MockObject;
use File::Basename;

my $conf = LoadFile("$Bin/conf/example.yaml");

Log::Log4perl->easy_init({ level => $DEBUG, layout => "%F{1}-%L: %m%n" });

my $store = PogoMockStore->new();
my $slot  = Test::MockObject->new();

my $secstore = Test::MockObject->new();
$secstore->fake_module(
    'Pogo::Dispatcher::AuthStore',
    instance => sub { return $secstore; },
    get      => sub {
        my($self, $key) = @_;
        return $self->{store}->{$key};
    },
    store    => sub {
        my($self, $key, $val) = @_;
        $self->{store}->{$key} = $val;
    },
);

my $ns = Pogo::Engine::Namespace->new(
  store    => $store,
  get_slot => $slot,
  nsname   => "wonk",
);

  # caches it under its name for subsequent lookups
Pogo::Engine->namespace( $ns );

$ns->set_conf($conf);
my $c = $ns->get_conf($conf);

use Data::Dumper;
# print Dumper( $c );

$ns->init();

Pogo::Engine->instance( { store => $store });
ok( 1, "at the end" );

my $job = Pogo::Engine::Job->new({
    store       => $store,
    invoked_as  => "",
    namespace   => $ns,
    target      => { host => "blah" }, #["mytarget-1", "mytarget-2"],
    user        => "fred",
    run_as      => "",
    password    => "",
    timeout     => "",
    job_timeout => "",
    command     => "",
    retry       => "",
    prehook     => "",
    posthook    => "",
    secrets     => "",
    email       => "",
    im_handle   => "",
    client      => "",
    requesthost => "",
    concurrent  => 1,
    exe_name    => "",
    exe_data    => "",
});

$job->start();

$Data::Dumper::Indent = 1;

$ns->fetch_runnable_hosts( 
    $job, 
    { "foo1.east.example.com" => { "bork" => 1 },
    },
    sub { INFO "err cont", Dumper( \@_ ); },
    sub { INFO "ok cont", Dumper( \@_ ); },
);

DEBUG $store->_dump();

1;

__END__

    qw(invoked_as namespace target user run_as password timeout job_timeout
    command retry prehook posthook secrets email im_handle client
    requesthost concurrent exe_name exe_data)
