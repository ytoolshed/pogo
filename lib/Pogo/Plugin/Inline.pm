package Pogo::Plugin::Inline;

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

sub new
{
  my ( $class, %opts ) = @_;
  return bless \%opts, $class;
}

sub expand_targets
{
  my ($self, $targets) = @_;
  my @flat;
  foreach my $target (@$targets)
  {
    push @flat, string_glob_permute($target);
  }

  my %uniq = ();
  @flat = grep { ! $uniq{ $_ }++ } @flat;
  return \@flat;
}

sub fetch_target_meta
{
  my ( $self, $target, $errc, $cont, $logcont ) = @_;
  my $hinfo = {};

  if ( !defined $self->{_target_cache}->{$target} )
  {
    # populate the cache anew - we might as well do it for all hosts
    my $conf = $self->{conf}->();

    foreach my $app ( sort keys %{ $conf->{apps} } )
    {
      foreach my $expression ( sort keys %{ $conf->{apps}->{$app} } )
      {
        foreach my $host ( string_glob_permute( $conf->{apps}->{$app}->{$expression} ) )
        {
          $hinfo->{$host}->{apps}->{$app} = 1;
        }
      }
    }

    foreach my $envtype ( sort keys %{ $conf->{envs} } )
    {
      foreach my $envname ( sort keys %{ $conf->{envs}->{$envtype} } )
      {
        foreach my $expression ( sort keys %{ $conf->{envs}->{$envtype}->{$envname} } )
        {
          foreach
            my $host ( string_glob_permute( $conf->{envs}->{$envtype}->{$envname}->{$expression} ) )
          {
            $hinfo->{$host}->{envs}->{$envtype}->{$envname} = 1;
          }
        }
      }
    }

    foreach my $target ( keys %$hinfo )
    {
      $self->{_target_cache}->{$target}->{apps} = [ keys %{ $hinfo->{$target}->{apps} } ];
      foreach my $envtype ( keys %{ $hinfo->{$target}->{envs} } )
      {
        $self->{_target_cache}->{$target}->{envs}->{$envtype} =
          $hinfo->{$target}->{envs}->{$envtype};
      }
    }
  }

  $cont->( $self->{_target_cache}->{$target} );
}

1;

=pod

=head1 NAME

Pogo::Plugin::Inline

=head1 SYNOPSIS

    my @hosts = 
       Pogo::Plugin::Inline->expand_targets( ["host[0-9].corp.com"] );

=head1 DESCRIPTION

Expands hostname patterns to an array of hostnames.

=head1 METHODS

B<expand_targets( [$pattern, ..] )>

=over 2

Expands 

=back

=head1 COPYRIGHT

Apache 2.0

=head1 AUTHORS

  Andrew Sloane <andy@a1k0n.net>
  Michael Fischer <michael+pogo@dynamine.net>
  Mike Schilli <m@perlmeister.com>
  Nicholas Harteau <nrh@hep.cat>
  Nick Purvis <nep@noisetu.be>
  Robert Phan robert.phan@gmail.com

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
