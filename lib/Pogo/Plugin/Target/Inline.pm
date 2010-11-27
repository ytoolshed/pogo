package Pogo::Plugin::Target::Inline;

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

use Data::Dumper;
use Log::Log4perl qw(:easy);
use String::Glob::Permute qw(string_glob_permute);

use base qw(Pogo::Plugin::Target);

sub get_apps
{
  my ( $self, $expressions ) = @_;
  DEBUG Dumper $expressions;
}

sub get_envs
{
  my ( $self, $expressions ) = @_;
  DEBUG Dumper $expressions;
}

sub expand_target
{
  my ( $self, $target ) = @_;

  my @flat;
  push @flat, string_glob_permute($target);

  # we also need to uniq this, methinks
  my %uniq = map { $_ => 1 } @flat;

  return keys %uniq;
}

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
