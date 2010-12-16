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

use Test::More 'no_plan';    #tests => 7;
use Test::Exception;

use Carp qw(confess);
use Data::Dumper;
use FindBin qw($Bin);
use LWP::UserAgent;

use lib "$Bin/../lib";
use lib "$Bin/lib";
use Pogo::Common;

$SIG{ALRM} = sub { confess; };
alarm(60);

use PogoTester qw(derp);
ok( my $pt = PogoTester->new(), "new pt" );

chdir($Bin);

ok( Log::Log4perl::init("$Bin/conf/log4perl.conf"), "log4perl" );

# check to see if httpd exists
my $has_httpd = $pt->httpd_exists();

# check to see if httpd is the correct version
my $ver_ok = 0;
SKIP:
{
  skip 'missing httpd', 1, unless $has_httpd;
  $ver_ok = $pt->check_httpd_version();
  ok( $ver_ok, 'httpd_version' );
}

SKIP:
{
  skip 'missing httpd',        4, unless $has_httpd;
  skip 'bad version of httpd', 4, unless $ver_ok;

  # generate our httpd.conf
  ok( my $baseuri = $pt->build_httpd_conf($Bin), 'httpd conf' );

  # start httpd
  $pt->stop_httpd($Bin);
  ok( $pt->start_httpd($Bin), 'httpd start' );

  # check httpd
  ok( my $ua = LWP::UserAgent->new(), 'new UA' );
  ok( my $res = $ua->get( $baseuri . '/index.html' ), 'get index.html' );
  ok( $res->is_success, "200 OK" );
  print Dumper $res;

}
