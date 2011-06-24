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

use common::sense;

use FindBin qw($Bin);

use lib "$Bin/../lib";

use Pogo::Engine;
use Log::Log4perl qw(:easy);
use YAML::XS qw(LoadFile);
use LWP::UserAgent;

# it's sorta lame to set up log4perl here, but inside the Engine stuff it's
# used extensively

Log::Log4perl::init(
  \q{
log4perl.rootLogger                      = DEBUG, screen
log4perl.appender.screen                 = Log::Log4perl::Appender::Screen
log4perl.appender.screen.stderr          = 0
log4perl.appender.screen.syswrite        = 0
log4perl.appender.screen.layout          = Log::Log4perl::Layout::PatternLayout
log4perl.appender.screen.layout.ConversionPattern = [%P] %p %F{2}:%L %m%n
}
);

if ( @ARGV < 3 )
{
  LOGDIE "usage: $0 <config> <namespace> <constraint.yaml>\n";
}

my $configf      = shift @ARGV;
my $namespace    = shift @ARGV;
my $constraintsf = shift @ARGV;

my $config      = LoadFile($configf)      || LOGDIE "cannot load $configf";
my $constraints = LoadFile($constraintsf) || LOGDIE "cannot load $constraintsf";
my $ns = Pogo::Engine->init($config)->namespace($namespace)->init->set_conf($constraints);

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

  Andrew Sloane <andy@a1k0n.net>
  Ian Bettinger <ibettinger@yahoo.com>
  Michael Fischer <michael+pogo@dynamine.net>
  Mike Schilli <m@perlmeister.com>
  Nicholas Harteau <nrh@hep.cat>
  Nick Purvis <nep@noisetu.be>
  Robert Phan <robert.phan@gmail.com>
  Srini Singanallur <ssingan@yahoo.com>
  Yogesh Natarajan <yogesh_ny@yahoo.co.in>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker

