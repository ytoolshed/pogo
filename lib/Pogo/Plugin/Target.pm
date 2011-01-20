package Pogo::Plugin::Target;

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

use 5.008;
use common::sense;

use AnyEvent;
use Log::Log4perl qw(:easy);

our $BATCH_SIZE = 200;

sub new
{
  my $class = shift;
  my $self  = {@_};

  bless $self, $class;
  return $self;
}

sub set_batch_size
{
  my ( $self, $batch_size ) = @_;
  $BATCH_SIZE = $batch_size;
}

sub _expand_targets
{
  my ( $self, $targets ) = @_;
  my @flat;
  foreach my $elem (@$targets)
  {
    push @flat, $self->expand_target($elem);
  }

  # we also need to uniq this, methinks
  my %uniq = map { $_ => 1 } @flat;

  return sort _hostsort keys %uniq;
}

sub _fetch_apps
{
  my ( $self, $targets, $errc, $cont ) = @_;
  my $info;

  my $cv = AnyEvent->condvar;

  DEBUG Dumper $targets;
  foreach my $target (@$targets)
  {
    $cv->send( $self->meta_for_host($target) );
    if ($info)
    {
      $cont->($info);
    }
    else
    {
      $errc->();
    }
  }
}

sub _fetch_envs
{

}

sub _hostsort
{
  my $ahost = join( '.', reverse split /[\.\-]/, $a );
  my $bhost = join( '.', reverse split /[\.\-]/, $b );

  return $ahost cmp $bhost
    || $a cmp $b;
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
