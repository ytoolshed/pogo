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
use Test::More tests => 18;

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

ok( Log::Log4perl::init("$Bin/conf/log4perl.conf"), "log4perl" );

use Pogo::Plugin::Planner::Default;

sub hsort
{

  ( my $a_nums = $a ) =~ s/(\d+)/ sprintf("%04d", $1) /ge;
  ( my $b_nums = $b ) =~ s/(\d+)/ sprintf("%04d", $1) /ge;

  my $ahost = join( '.', reverse split /[\.\-]/, $a_nums );
  my $bhost = join( '.', reverse split /[\.\-]/, $b_nums );

  return $ahost cmp $bhost
    || $a cmp $b;
}

sub conf_read {
    my $conf_file = "$Bin/conf/example.yaml";
    my $data = LoadFile( $conf_file );
}

my $pl = Pogo::Plugin::Planner::Default->new();
$pl->conf( \&conf_read );

my $result;
my $target = "foo97.east.example.com";
my $data = $pl->fetch_target_meta(
    [$target],
    "somenamespace",
    sub { print "in errsub\n"; },
    sub { $result = $_[0] },
);

is( ref($result), "HASH", "fetch_target_meta on yaml" );
is( $result->{$target}->{apps}->[0], 
    "frontend", "fetch_target_meta on yaml" );
is( $result->{$target}->{envs}->{coast}->{east}, "1", 
    "fetch_target_meta on yaml" );

my %input = (
  'foo[1-2]'     => [ sort hsort ( 'foo1', 'foo2' ) ],
  'foo[3,4]'     => [ sort hsort ( 'foo3', 'foo4' ) ],
  'foo[8,10,33]' => [ sort hsort ( 'foo8', 'foo10', 'foo33' ) ],
  'bar[1-9]' => [ sort hsort map {"bar$_"} ( 1 .. 9 ) ],
  'host[01-10]' => [ sort hsort map { sprintf "host%02d", $_ } ( 1 .. 10 ) ],
  'host[01-10].foo{bar,baz}' => eval {
    my @res = map { sprintf "host%02d.foobar", $_ } ( 1 .. 10 );
    push( @res, map { sprintf "host%02d.foobaz", $_ } ( 1 .. 10 ) );
    @res = sort hsort @res;
    return \@res;
  },
);

while ( my ( $expr, $res ) = each %input )
{
  my $flat      = Pogo::Plugin::Planner::Default->expand_targets( [$expr] );
  my $size_flat = scalar @$flat;
  my $size_expr = scalar @$res;
  is( $size_flat, $size_expr, "$expr size" )
    or print STDERR Dumper { flat => $flat, res => $res };
  is_deeply( $flat, $res, "$expr expand" )
    or print STDERR Dumper { flat => $flat, res => $res };
}

my $all_expr = [ sort hsort keys %input ];
my @all_res;
foreach my $res ( @input{ @$all_expr } ) { push @all_res, @$res; }

my $all_flat      = Pogo::Plugin::Planner::Default->expand_targets($all_expr);
my $all_res_size  = scalar @all_res;
my $all_flat_size = scalar @$all_flat;

is( $all_res_size, $all_flat_size, "all size" )
  or print STDERR Dumper { flat => $all_flat, res => \@all_res };
is_deeply( $all_flat, \@all_res, "all expr" )
  or print STDERR Dumper { flat => $all_flat, res => \@all_res };

1;

=pod

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
