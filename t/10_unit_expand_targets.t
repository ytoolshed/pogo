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

use Test::More 'no_plan';

use Data::Dumper;
use FindBin qw($Bin);
use JSON;
use Log::Log4perl qw(:easy);
use Net::SSLeay qw();
use YAML::XS qw(LoadFile);
use Sys::Hostname qw(hostname);

use lib "$Bin/lib/";
use lib "$Bin/../lib/";

chdir($Bin);

ok( Log::Log4perl::init("$Bin/conf/log4perl.conf"), "log4perl" );

use Pogo::Engine::Job;

sub hsort
{
  my $ahost = join( '.', reverse split /[\.\-]/, $a );
  my $bhost = join( '.', reverse split /[\.\-]/, $b );

  return $ahost cmp $bhost
    || $a cmp $b;
}

my %input = (
  'foo[1-2]'     => [ sort hsort ( 'foo1', 'foo2' ) ],
  'foo[3,4]'     => [ sort hsort ( 'foo3', 'foo4' ) ],
  'foo[8,10,33]' => [ sort hsort ( 'foo8', 'foo10', 'foo33' ) ],
  'bar[1-10]' => [ sort hsort map {"bar$_"} ( 1 .. 10 ) ],
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
  my @flat = Pogo::Engine::Job::_expand_targets( [$expr] );
  $size_flat = scalar @flat;
  $size_expr = scalar @$res;
  ok( $size_flat == $size_expr, "$expr size" )
    or print STDERR Dumper { flat => \@flat, res => $res };
  is_deeply( \@flat, $res, "$expr expand" )
    or print STDERR Dumper { flat => \@flat, res => $res };
}

my $all_expr = [ keys %input ];
my @all_res;
foreach my $res ( values %input ) { push @all_res, @$res; }
@all_res = sort hsort @all_res;

my @all_flat      = Pogo::Engine::Job::_expand_targets($all_expr);
my $all_res_size  = scalar @all_res;
my $all_flat_size = scalar @all_flat;

ok( $all_res_size == $all_flat_size, "all size" )
  or print STDERR Dumper { flat => \@all_flat, res => \@all_res };
is_deeply( \@all_flat, \@all_res, "all expr" )
  or print STDERR Dumper { flat => \@all_flat, res => \@all_res };

1;

=pod

=head1 NAME

  CLASSNAME - SHORT DESCRIPTION

=head1 SYNOPSIS

CODE GOES HERE

=head1 DESCRIPTION

LONG_DESCRIPTION

=head1 METHODS

B<methodexample>

=over 2

methoddescription

=back

=head1 SEE ALSO

L<Pogo::Dispatcher>

=head1 COPYRIGHT

Apache 2.0

=head1 AUTHORS

  Andrew Sloane <asloane@yahoo-inc.com>
  Michael Fischer <mfischer@yahoo-inc.com>
  Nicholas Harteau <nrh@yahoo-inc.com>
  Nick Purvis <nep@yahoo-inc.com>
  Robert Phan <rphan@yahoo-inc.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
