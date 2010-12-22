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
use YAML::XS qw(Load LoadFile);

use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoTester;

$SIG{ALRM} = sub { confess; };
alarm(60);

use Pogo::Engine;

test_pogo {
  my $valid   = {};
  my $invalid = {};

  #{{{ VALID1
  $valid->{valid1} = <<___VALID1___;
# example constraints
---
plugins:
apps:
  frontend:
    - foo[1-100].east.example.com
    - foo[1-100].west.example.com
  backend:
    - bar[1-10].east.example.com
    - bar[1-10].west.example.com

envs:
  coast:
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
---   # minimal constraints should be valid
plugins:
apps:
envs:
constraints:
___VALID2___

  #}}}
  #{{{ VALID3
  $valid->{valid3} = <<___VALID3___;
# example constraints
---
{} # minimal constraints should be valid
___VALID3___

  #}}}
  #{{{ INVALID1
  $invalid->{invalid1} = <<___INVALID1___;
# example constraints
---
apps:
  frontend:
    - foo[1-100].east.example.com
    - foo[1-100].west.example.com
  backend:
    - bar[1-10].east.example.com
    - bar[1-10].west.example.com

envs:
  coast:
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
app:        # <--- should be 'apps' not 'app'
  frontend:
    - foo[1-100].east.example.com
    - foo[1-100].west.example.com
  backend:
    - bar[1-10].east.example.com
    - bar[1-10].west.example.com

envs:
  coast:
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
apps:
  frontend:
    - foo[1-100].east.example.com
    - foo[1-100].west.example.com
  backend:
    - bar[1-10].east.example.com
    - bar[1-10].west.example.com

envs:
  coast:
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
apps:
  frontend:
    - foo[1-100].east.example.com
    - foo[1-100].west.example.com
  backend:
    - bar[1-10].east.example.com
    - bar[1-10].west.example.com

envs:
  coast:
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
  # {{{ validity testing

  foreach my $cname ( sort keys %$valid )
  {

    my $namespace = $cname;
    my $disp_conf;
    my ( $gotconf, $const_conf, $r, $ns ) = ( undef, undef, undef, undef );
    lives_ok { $disp_conf = LoadFile("$Bin/conf/dispatcher.conf"); } 'load dispatcher conf';

    # first test non-rpc
    lives_ok { $const_conf = Load( $valid->{$cname} ); } "$cname eval yaml";
    lives_ok { $ns = Pogo::Engine->init($disp_conf)->loadconf( $namespace, $const_conf ); } "$cname set_conf";
    lives_ok { $gotconf = Pogo::Engine->namespace($namespace)->get_conf; } "$cname get_conf";

    # now test rpc
    undef $gotconf;
    ok( $r = dispatcher_rpc( [ 'loadconf', $namespace, $const_conf ] ), "$cname rpc loadconf" );
    ok( $r->[0]->{status} eq 'OK', "$cname rpc loadconf OK: " . $r->[0]->{errmsg} );
    ok( $gotconf = Pogo::Engine->namespace($namespace)->get_conf, "$cname rpc get_conf" );
  }

  #my $config = LoadFile($configf) || LOGDIE "cannot load $configf";
  #my $constraints = LoadFile($constraintsf) || LOGDIE "cannot load $constraintsf";
  #my $ns = Pogo::Engine->init($config)->namespace($namespace)->init->set_conf($constraints);

  # }}}
  # {{{ invalidity testing

  # }}}
  # {{{ plugin testing

  my $disp_conf;
  my $config;
  ok( $config = LoadFile("$Bin/conf/example.yaml"), "plugin load yaml" );
  lives_ok { $disp_conf = LoadFile("$Bin/conf/dispatcher.conf"); } 'load dispatcher conf';
  Pogo::Engine->init($disp_conf)->namespace('example')->set_conf($config);

  # }}}
};

done_testing;

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

