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

use Data::Dumper;

use common::sense;

use Test::More 'no_plan';
use Test::Exception;

use FindBin qw($Bin);
use JSON;
use Log::Log4perl qw(:easy);
use Net::SSLeay qw();
use Sys::Hostname qw(hostname);
use YAML::XS qw(Load LoadFile);

use lib "$Bin/lib/";
use lib "$Bin/../lib/";

use Pogo::Engine;
use PogoTester qw(derp);

ok( my $pt = PogoTester->new(), "new pt" );
chdir($Bin);
ok( Log::Log4perl::init("$Bin/conf/log4perl.conf"), "log4perl" );
my $js = JSON->new;
my $valid = {};
my $invalid = {};

ok( $pt->start_dispatcher, 'stop dispatcher' );

#{{{ VALID1
$valid->{valid1} = <<___VALID1___;
# example constraints
---
valid1:
  apps:
    frontend:
      inline:
        - foo[1-100].east.example.com
        - foo[1-100].west.example.com
    backend:
      inline:
        - bar[1-10].east.example.com
        - bar[1-10].west.example.com

  envs:
    coast:
      inline:
        east:
          - foo[1-100].east.example.com
          - bar[1-10].east.example.com
        west:
          - foo[1-100].west.example.com
          - bar[1-10].west.example.com

  constraints:
    coast:
      concurrency:
        - frontend: 25%
        - backend: 1
      sequence:
        - [ backend, frontend ]
___VALID1___

#}}}
#{{{ VALID2
$valid->{valid2} = <<___VALID2___;
# example constraints
---
valid2:  # minimal constraints should be valid
  apps:
  envs:
  constraints:
___VALID2___

#}}}
#{{{ VALID3
$valid->{valid3} = <<___VALID3___;
# example constraints
---
valid3:  # minimal constraints should be valid
___VALID3___

#}}}
#{{{ VALID4
$valid->{valid4} = <<___VALID4___;
# example constraints
---
# minimal constraints should be valid
___VALID4___

#}}}
#{{{ INVALID1
$invalid->{invalid1} = <<___INVALID1___;
# example constraints
---
invalid1:
  apps:
    frontend:
      inline:
        - foo[1-100].east.example.com
        - foo[1-100].west.example.com
    backend:
      inline:
        - bar[1-10].east.example.com
        - bar[1-10].west.example.com

  envs:
    coast:
      inline:
        east:
          - foo[1-100].east.example.com
          - bar[1-10].east.example.com
        west:
          - foo[1-100].west.example.com
          - bar[1-10].west.example.com

  constraints:
    coast:
      concurrency:
        - front: 25%      # <-- here we reference an application that doesn't exist
        - backend: 1
      sequence:
        - [ backend, frontend ]
___INVALID1___

#}}}
#{{{ INVALID2
$invalid->{invalid2} = <<___INVALID2___;
# example constraints
---
invalid2:
  app:        # <--- should be 'apps' not 'app'
    frontend:
      inline:
        - foo[1-100].east.example.com
        - foo[1-100].west.example.com
    backend:
      inline:
        - bar[1-10].east.example.com
        - bar[1-10].west.example.com

  envs:
    coast:
      inline:
        east:
          - foo[1-100].east.example.com
          - bar[1-10].east.example.com
        west:
          - foo[1-100].west.example.com
          - bar[1-10].west.example.com

  constraints:
    coast:
      concurrency:
        - frontend: 25%
        - backend: 1
      sequence:
        - [ backend, frontend ]
___INVALID2___

#}}}
#{{{ INVALID3
$invalid->{invalid3} = <<___INVALID3___;
# example constraints
---
invalid3:
  apps:
    frontend:
      inline:
        - foo[1-100].east.example.com
        - foo[1-100].west.example.com
    backend:
      inline:
        - bar[1-10].east.example.com
        - bar[1-10].west.example.com

  envs:
    coast:
      inline:
        east:
          - foo[1-100].east.example.com
          - bar[1-10].east.example.com
        west:
          - foo[1-100].west.example.com
          - bar[1-10].west.example.com

  constraints:
    coast:
      concurrency:  # <-- concurrency is supposed to be an array
        frontend: 25%
        backend: 1
      sequence:
        - [ backend, frontend ]
___INVALID3___

#}}}
#{{{ INVALID4
$invalid->{invalid4} = <<___INVALID4___;
# example constraints
---
apps:  #<-- missing top-level 'deployment' hash
  frontend:
    inline:
      - foo[1-100].east.example.com
      - foo[1-100].west.example.com
  backend:
    inline:
      - bar[1-10].east.example.com
      - bar[1-10].west.example.com

envs:
  coast:
    inline:
      east:
        - foo[1-100].east.example.com
        - bar[1-10].east.example.com
      west:
        - foo[1-100].west.example.com
        - bar[1-10].west.example.com

constraints:
  coast:
    concurrency:  # <-- concurrency is supposed to be an array
      frontend: 25%
      backend: 1
    sequence:
      - [ backend, frontend ]
___INVALID4___

#}}}

foreach my $cname ( sort keys %$valid )
{

  my $namespace = $cname;
  my $disp_conf;
  my ( $gotconf, $const_conf, $r, $ns ) = (undef, undef, undef, undef);
  lives_ok { $disp_conf = LoadFile("$Bin/conf/dispatcher.conf"); } 'load dispatcher conf';

  # first test non-rpc
  lives_ok { $const_conf = Load($valid->{$cname}); } "$cname eval yaml";
  ok( $ns = Pogo::Engine->init($disp_conf)->loadconf( $namespace, $const_conf ), "$cname set_conf" );
  ok( $gotconf = Pogo::Engine->namespace($namespace)->get_conf, "$cname get_conf" );

  # now test rpc
  undef $gotconf;
  ok( $r = $pt->dispatcher_rpc( [ 'loadconf', $namespace, $const_conf ] ), "$cname rpc loadconf" );
  ok( $r->[0]->{status} eq 'OK', "$cname rpc loadconf OK" );
  ok( $gotconf = Pogo::Engine->namespace($namespace)->get_conf, "$cname rpc get_conf" );
}

#my $config = LoadFile($configf) || LOGDIE "cannot load $configf";
#my $constraints = LoadFile($constraintsf) || LOGDIE "cannot load $constraintsf";
#my $ns = Pogo::Engine->init($config)->namespace($namespace)->init->set_conf($constraints);

ok( $pt->stop_dispatcher, 'stop dispatcher' );

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

