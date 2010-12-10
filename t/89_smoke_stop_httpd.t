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
use Test::More tests => 4;

use Carp qw(confess);
use Data::Dumper;
use FindBin qw($Bin);

use lib "$Bin/../lib";
use lib "$Bin/lib";

$SIG{ALRM} = sub { confess; };
alarm(60);

use PogoTester qw(derp);
ok( my $pt = PogoTester->new(), "new pt" );

chdir($Bin);

ok( Log::Log4perl::init("$Bin/conf/log4perl.conf"), "log4perl" );

# check to see if httpd exists
my $has_httpd = $pt->httpd_exists();

SKIP: {
  skip 'missing httpd', 2, unless $has_httpd;

  # stop httpd
  ok( $pt->stop_httpd( $Bin ), 'stop httpd' );

  # make sure it's stopped
  ok( ! $pt->check_httpd(), 'httpd stopped' );

  # clear out the error_log
  my $error_log = "$Bin/apache/logs/error_log";
  if( open(my $FH, '>', $error_log) ) { close( $FH ); }
}
