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
use Net::SSLeay qw/sslcat/;
use Log::Log4perl qw/:easy/;

use YAML::Syck qw/LoadFile/;
use FindBin qw/$Bin/;
use JSON;
use IO::Socket::INET;
use Data::Dumper;

use lib "$Bin/lib/";

use PogoTester;

chdir($Bin);

my $js = JSON->new;

# start pogo-dispatcher
ok( PogoTester::start_dispatcher, 'start' );

my $conf;
eval { $conf = LoadFile("$Bin/conf/dispatcher.conf"); };
ok( !$@, "loadconf" );

ok( $conf->{worker_port}    =~ m/^\d+/, "parse worker port" );
ok( $conf->{rpc_port}       =~ m/^\d+/, "parse rpc port" );
ok( $conf->{authstore_port} =~ m/^\d+/, "parse authstore port" );

foreach my $portname qw/worker_port rpc_port authstore_port/
{
  my $port = $conf->{$portname};

  my @resp;
  eval { @resp = sslcat( '127.0.0.1', $port, $js->encode(["ping"])); };
  ok( !$@, "$portname sslcat" );

  my $pong;
  eval { $pong = $js->decode($resp[0]); };
  ok( !$@ && $pong, "decode $portname" );
  ok( $pong->[0] eq 'pong', "pong $portname" );

}

# stop
ok( PogoTester::stop_dispatcher, 'stop' );

1;

