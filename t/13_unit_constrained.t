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
use Test::More tests => 8;
use Test::Deep;

use Carp qw(confess);
use Data::Dumper;
use FindBin qw($Bin);
use Log::Log4perl qw(:easy);
use Net::SSLeay qw();
use Sys::Hostname qw(hostname);
use YAML::XS qw(Load LoadFile);
use JSON qw(encode_json);
use AnyEvent;

use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoTesterAlarm;
use PogoMockStore;
use PogoMockAuthStore;

use Pogo::Engine;
use Pogo::Engine::Namespace;
use Pogo::Engine::Job;

use Test::MockObject;
use File::Basename;

use Pogo::Engine::Store qw(store);
use Data::Dumper;

# Log::Log4perl->easy_init({ level => $DEBUG, layout => "%F{1}-%L-%M: %m%n" });

my $ns = Pogo::Engine::Namespace->new(
  nsname   => "wonk",
);

$ns->init();

my $conf = LoadFile("$Bin/conf/example.yaml");
$ns->set_conf($conf);

$ns->init();

Pogo::Engine->instance();

my $target = "foo[1-4].east.example.com";

my $target_href = $ns->expand_targets( [$target] );
my @target_range = qw(
foo1.east.example.com
foo2.east.example.com
foo3.east.example.com
foo4.east.example.com);

cmp_deeply( $target_href, \@target_range, "target range" );

$target = [qw(foo13.east.example.com 
        bar3.east.example.com
        foo13.west.example.com
        bar3.west.example.com
    )];

my $host_meta;

$ns->fetch_target_meta(
    $target,
    $ns->name,
    sub { die "err"; },
    sub { ($host_meta) = @_;
          ok(1, "success"); 
        },
);

is( $host_meta->{"foo13.west.example.com"}->{apps}->[0], "frontend",
    "fetch_target_meta" );
is( $host_meta->{"foo13.west.example.com"}->{envs}->{coast}->{west}, 1,
    "fetch_target_meta" );
is( $host_meta->{"foo13.east.example.com"}->{envs}->{coast}->{east}, 1,
    "fetch_target_meta" );
is( $host_meta->{"bar3.west.example.com"}->{apps}->[0], "backend",
    "fetch_target_meta" );

my $result;

$ns->fetch_target_meta(
    $target,
    $ns->name,
    sub { die "err"; },
    sub { ($host_meta) = @_;
          ok(1, "success"); 
        },
);

my $job = Pogo::Engine::Job->new({
    invoked_as  => "gonzo",
    namespace   => $ns->name,
    target      => $target,
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
    #concurrent  => 1,
    exe_name    => "blech",
    exe_data    => "wonk",
});

$ns->fetch_runnable_hosts( 
    $job, 
    $host_meta,
    sub { die "err cont: ", Dumper( \@_ ); },
    sub { $result = \@_;
        },
);

ok(1, "at the end" );

# print store->_dump();

__END__

$job->start(
     sub { ok 0, "err cont on start(): @_" },
     sub { ok 1, "success cont on start()"; 
           my($nqueued, $nwaiting) = @_;
           is($nqueued, 4, "4 hosts enqueued");
           is($nwaiting, 0, "0 hosts waiting");
         },
);

print Dumper($result);

__END__

$job->start(
     sub { ok 0, "err cont on start(): @_" },
     sub { ok 1, "success cont on start()"; 
           my($nqueued, $nwaiting) = @_;
           is($nqueued, 4, "4 hosts enqueued");
           is($nwaiting, 0, "0 hosts waiting");
         },
);

ok 1, "At the end";

__END__
$Data::Dumper::Indent = 1;

$job->set_host_state( $job->{_hosts}->{"foo1.east.example.com"}, "waiting" );
$job->set_host_state( $job->{_hosts}->{"foo2.east.example.com"}, "waiting" );

1;
