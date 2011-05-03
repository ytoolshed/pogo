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
use Test::More tests => 3;

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
use Log::Log4perl qw(:easy);

# Log::Log4perl->easy_init({ level => $DEBUG, layout => "%F{1}-%L: %m%n",
#    file => "stdout" });

  # Pogo::Dispatcher::AuthStore mockery
my $secstore = Test::MockObject->new();
$secstore->fake_module(
    'Pogo::Dispatcher::AuthStore',
    instance => sub { return $secstore; },
);
$secstore->mock(get => sub {
        my($self, $key) = @_;
        return $self->{store}->{$key};
    });
$secstore->mock(store => sub {
        my($self, $key, $val) = @_;
        $self->{store}->{$key} = $val;
    });

my $ns = Pogo::Engine::Namespace->new(
  nsname   => "wonk",
);

$ns->init();

my $conf = LoadFile("$Bin/conf/example.yaml");
$ns->set_conf($conf);
my $c = $ns->get_conf($conf);

use Data::Dumper;

$ns->init();

Pogo::Engine->instance();

my $job = Pogo::Engine::Job->new({
    invoked_as  => "gonzo",
    namespace   => $ns->name,
    target      => ["foo[1-4].east.example.com"],
    user        => "fred",
    run_as      => "weeble",
    password    => "secret",
    timeout     => "2",
    job_timeout => 10,
    command     => "ls",
    retry       => "1",
    prehook     => "",
    posthook    => "",
    secrets     => "",
    email       => "",
    im_handle   => "",
    client      => "",
    requesthost => "",
    concurrent  => 2,
    exe_name    => "blech",
    exe_data    => "wonk",
});

$job->start(
     sub { ok 0, "err cont on start(): @_" },
     sub { ok 1, "success cont on start()"; 
           my($nqueued, $nwaiting) = @_;
           is($nqueued, 4, "4 hosts enqueued");
           is($nwaiting, 0, "0 hosts waiting");
         },
);

__END__
$Data::Dumper::Indent = 1;

$job->set_host_state( $job->{_hosts}->{"foo1.east.example.com"}, "waiting" );
$job->set_host_state( $job->{_hosts}->{"foo2.east.example.com"}, "waiting" );

$ns->fetch_runnable_hosts( 
    $job, 
    { "foo1.east.example.com" => { "bork" => 1 },
      "foo2.east.example.com" => { "bork" => 1 },
    },
    sub { ok 0, "err cont: " . Dumper( \@_ ); },
    sub { is( $_[0]->[0], "foo1.east.example.com", "host is runnable" );
          DEBUG store()->_dump;
          DEBUG Dumper( \@_ );
        },
);

1;
