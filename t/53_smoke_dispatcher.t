#!/usr/bin/env perl -w

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

use 5.008;
use common::sense;

use Test::Exception;
use Test::More;

use Carp qw(confess);
use FindBin qw($Bin);
use Log::Log4perl qw(:easy);
use Sys::Hostname qw(hostname);
use YAML::XS qw(LoadFile);

use PogoTester;

$SIG{ALRM} = sub { confess; };
alarm(60);

test_pogo {
    my $t;

    # ping
    $t = dispatcher_rpc( ["ping"] );
    ok( $t->[1]->[0] == 0xDEADBEEF, 'ping' )
      or print Dumper $t;

    # stats
    $t = dispatcher_rpc( ["stats"] );
    ok( $t->[1]->[0]->{hostname} eq hostname(), 'stats' )
      or print Dumper $t;

    # badcmd
    $t = dispatcher_rpc( ["weird"] );
    ok( $t->[0]->{status} eq 'ERROR', 'weird' )
      or print Dumper $t;
    ok( $t->[0]->{errmsg} eq qq/unknown rpc command 'weird'/, 'weird 2' );

    # loadconf
    my $conf_to_load = LoadFile("$Bin/conf/example.yaml");
    $t = dispatcher_rpc( [ "loadconf", 'example', $conf_to_load ] )
      or print Dumper $t;
    ok( $t->[0]->{status} eq 'OK', "loadconf rpc ok" ) or print Dumper $t;
};

done_testing;

1;

