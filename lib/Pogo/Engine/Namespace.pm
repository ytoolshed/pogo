package Pogo::Engine::Namespace;

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

use strict;
use warnings;

use List::Util qw(min max);
use Log::Log4perl qw(:easy);

use Pogo::Engine::Namespace::Slot;

# Naming convention:
# get_* retrieves something synchronously
# fetch_* retrieves something asynchronously, taking an error callback
# and a continuation as the last two args

sub new
{
  my ( $class, $nsname ) = @_;
  my $self = {
    ns    => $nsname,
    path  => "/pogo/ns/$nsname",
    slots => {},
  };

  return bless $self, $class;
}

sub init
{
  my $self  = shift;
  my $store = Pogo::Engine->store;

  my $ns = $self->{ns};
  if ( !$store->exists( $self->path ) )
  {
    $store->create( $self->path, '' )
      or LOGDIE "unable to create namespace '$ns': " . $store->get_error;
    $store->create( $self->path . '/env', '' )
      or LOGDIE "unable to create namespace '$ns': " . $store->get_error;
    $store->create( $self->path . '/lock', '' )
      or LOGDIE "unable to create namespace '$ns': " . $store->get_error;
    $store->create( $self->path . '/conf', '' )
      or LOGDIE "unable to create namespace '$ns': " . $store->get_error;
  }

  return $self;
}

sub name
{
  return shift->{ns};
}

sub _has_constraints
{
  my ( $self, $app, $k ) = @_;
  my $store = Pogo::Engine->store;

  # TODO: potential optimization, cache these to avoid probing storage
  if ( !defined $k )
  {
    return $store->exists( $self->path( '/conf/constraints/', $app ) );
  }
  else
  {
    return $store->exists( $self->path("/conf/constraints/$app/$k") );
  }

  return;
}

sub unlock_job
{
  my ( $self, $job ) = @_;
  my $store = Pogo::Engine->store;

  foreach my $env ( $store->get_children( $self->path('/env/') ) )
  {
    foreach my $jobhost ( $store->get_children( $self->path( '/env/', $env ) ) )
    {
      my ( $host_jobid, $hostname ) = split /_/, $jobhost;
      if ( $job->id eq $host_jobid )
      {
        $store->delete( $self->path("/env/$env/$jobhost") );
      }
    }

    $store->delete( $self->path( '/env/', $env ) );
  }
}

# sequences

sub is_sequence_blocked
{
  my ( $self, $job, $host ) = @_;

  my $store = Pogo::Engine->store;
  my ( $nblockers, @bywhat ) = (0);

  foreach my $env ( @{ $host->info->{env} } )
  {
    my $k = $env->{key};
    my $v = $env->{value};

    foreach my $app ( @{ $host->info->{apps} } )
    {
      my @preds = $store->get_children( $self->path("/conf/sequences/pred/$k/$app") );
      foreach my $pred (@preds)
      {
        my $n = $store->get_children( $job->{path} . "/seq/$pred" . "_$k" . "_$v" );
        if ($n)
        {
          $nblockers += $n;
          push @bywhat, "$k $v $pred";
        }
      }
    }
  }
  return ( $nblockers, join( ', ', @bywhat ) );    # cosmetic, this is what shows up in the UI
}

sub get_seq_successors
{
  my ( $self, $envk, $app ) = @_;
  my $store = Pogo::Engine->store;

  my @successors = ($app);
  my @results;

  while (@successors)
  {
    $app = pop @successors;
    my @s = $store->get_children( $self->path("/conf/sequences/succ/$envk/$app") );
    push @results,    @s;
    push @successors, @s;
  }

  return @results;
}

# apps

sub filter_apps
{
  my ( $self, $apps ) = @_;
  my $store = Pogo::Server->store;

  my %constraints = map { $_ => 1 } $store->get_children( $self->path('/conf/constraints') );

  # FIXME: if you have sequences for which there are no constraints, we might
  # improperly ignore them here.  Can't think of a straightforward fix and
  # can't tell whether it will ever be a problem, so leaving for now.

  return [ grep { exists $constraints{$_} } @$apps ];
}

# config stuff
sub parse_appgroups
{
}

# i'm not sure we need this if we move to the new config format
#{{{ appgroup stuff
sub translate_appgroups
{
  my ( $self, $apps ) = @_;
  my $store = Pogo::Server->store;

  my %g;

  foreach my $app (@$apps)
  {
    my @groups = $store->get_children( $self->path("/conf/appgroups/byrole/$app") );
    if (@groups)
    {
      map { $g{$_} = 1 } @groups;
    }
    else
    {
      $g{$app} = 1;
    }
  }

  return [ keys %g ];
}

sub appgroup_members
{
  my ( $self, $appgroup ) = @_;
  my $store = Pogo::Engine->store;

  my @members = $store->get_children( $self->path("/conf/appgroups/bygroup/$appgroup") );

  return @members if @members;
  return $appgroup;
}

#}}}

# remove active host from all environments
# apparently this is deprecated?
sub unlock_host    # {{{ deprecated unlock_host
{
  my ( $self, $job, $host, $unlockseq ) = @_;
  my $store = Pogo::Server->store;

  return LOGDIE "unlock_host is deprecated";

  # iterate over /pogo/host/$host/<children>
  my $path = "/pogo/job/$host/host/$host";
  return unless $store->exists($path);

  my $n = 0;
  foreach my $child ( $store->get_children($path) )
  {
    next if substr( $child, 0, 1 ) eq '_';

    # get the node contents $app, $k, $v
    my $child_path = $path . '/' . $child;

    if ( substr( $child, 0, 4 ) eq 'seq_' )
    {
      next unless $unlockseq;

      # remove sequence lock
      my $node = substr( $child, 4 );
      $store->delete("/pogo/job/$job/seq/$node/$host");
      if ( ( scalar $store->get_children("/pogo/job/$job/seq/$node") ) == 0 )
      {
        $store->delete("/pogo/job/$job/seq/$node");
      }
    }
    else
    {
      my $job_host = $job->id . '_' . $host;

      # remove environment lock
      # delete /pogo/env/$app_$k_$v
      $store->delete("/pogo/env/$child/$job_host")
        or ERROR "unable to remove '/pogo/env/$child/$job_host' from '$child_path': "
        . $store->get_error;

      # clean up empty env nodes
      if ( ( scalar $store->get_children("/pogo/env/$child") ) == 0 )
      {
        $store->delete("/pogo/env/$child");
      }
    }

    $store->delete($child_path)
      or LOGDIE "unable to remove $child_path: " . $store->get_error;
    $n++;
  }

  return $n;
}    # }}}

# lazy
sub path
{
  my ( $self, @parts ) = @_;
  return join( '', $self->{path}, @parts );
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
