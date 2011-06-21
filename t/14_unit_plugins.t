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

use Test::More;
use Test::Exception;

use Carp qw(confess);
use Data::Dumper;
use FindBin qw($Bin);
use Log::Log4perl qw(:easy);

use lib "$Bin/lib";
use lib "$Bin/../lib";

use PogoTesterAlarm;

chdir($Bin);
diag("dir: $Bin");
ok( Log::Log4perl::init("$Bin/conf/log4perl.conf"), "log4perl" );
use_ok( 'Pogo::Plugin', 'use Pogo::Plugin' );

my $html =
  'here is some <b>marked up</b> HTML that needs <blink style="font-face:bold;">encoding</blink>';

# test that HTML encoder plugin is loaded and works
ok( my $encoder = Pogo::Plugin->load( 'HTMLEncode', { required_methods => ['html_encode'] } ),
  'load HTMLEncode plugins' );
diag( "HTML snippet before and after encoding:\n####### $html\n####### "
    . $encoder->html_encode($html) );
# this is not a comprehensive HTML -encoding test, just checking that we loaded something minimally functional
unlike( $encoder->html_encode($html), qr{[<>]}, 'HTML characters (<,>) removed' );

# test that our test directory -only (t/lib/Pogo/Plugin/SomePluginType/) SomePluginType plugins are checked and loaded as expected.
ok(
  my $test_plugin =
    Pogo::Plugin->load( 'SomePluginType', { required_methods => ['do_stuff'], multiple => 1 } ),
  'load SomePluginType plugin'
);
like(
  $test_plugin->do_stuff(),
  qr{Pogo::Plugin::SomePluginType::Two},
  'Pogo::Plugin::SomePluginType::Two module was selected'
);

# test loading multiple plugins
ok(
  my @multi_plugins = Pogo::Plugin->load_multiple(
    'MultiPlugin', { required_methods => [ 'do_stuff', 'multi_stuff' ] }
  ),
  'load MultiPlugin plugins'
);
is( scalar @multi_plugins, 3, 'got three (3) MultiPlugin plugins' );
like(
  Pogo::Plugin->load( 'MultiPlugin', { required_methods => [ 'do_stuff', 'multi_stuff' ] } )
    ->multi_stuff(),
  qr{Pogo::Plugin::MultiPlugin::Three},
  'Pogo::Plugin::MultiPlugin::Three was selected'
);

# test that bad plugins cause death
throws_ok(
  sub { Pogo::Plugin->load( 'BadPlugin', { required_methods => ['do_stuff'] } ) },
  qr{Fix the associated \.pm file or remove it\.},
  'fail to load non-valid BadPlugin plugins, with correct exception thrown'
);

done_testing();
