package Pogo::Engine;

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

use Log::Log4perl qw(:easy);
use JSON qw(from_json);

use Pogo::Engine::Job;
use Pogo::Engine::Namespace;
use Pogo::Engine::Store;

our $instance;
our %nscache;

sub instance
{
  return $instance if defined $instance;

  my ( $class, $opts ) = @_;
  DEBUG "new Pogo::Engine instance";

  $instance = {
    client_min => $opts->{client_min} || '0.0.0',
    start_time => time(),
  };

  $instance->{store} = Pogo::Engine::Store->new($opts);

  return bless $instance, $class;
}

sub store
{
  LOGDIE "not yet initialized" unless defined $instance;
  return $instance->{store};
}

# i guess we don't do anything yet.
sub start
{
  return;
}

# these are methods that can either be called on the engine instance, or via RPC
sub stats
{
  my @total_stats;
  foreach my $host ( $instance->store->get_children('/pogo/stats') )
  {
    my $path = '/pogo/stats/' . $host . '/current';
    if ( !$instance->store->exists($path) )
    {
      push( @total_stats, { hostname => $host, state => 'not connected' } );
      next;
    }

    my $raw_stats = $instance->store->get($path)
      or WARN "race condition? $path should exist but doesn't: " . $instance->store->get_error;

    my $host_stats;
    eval { $host_stats = from_json($raw_stats) };
    if ($@)
    {
      WARN "json decode of $path failed: $@";
      next;
    }
    push( @total_stats, $host_stats );
  }

  return \@total_stats;
}

sub lastjob
{
  my ( $self, $matchopts ) = @_;
  $matchopts->{limit} = 1;
  my @jobs = $self->listjobs($matchopts);

  return if ( !@jobs );
  my $lastjob = pop(@jobs);

  return $lastjob->{jobid};
}

sub listjobs
{
  my ( $self, $matchopts ) = @_;

  my @jobs;

  my $limit  = delete $matchopts->{limit}  || 100;
  my $offset = delete $matchopts->{offset} || 0;
  my $jobidx = _get_children_version("/pogo/job") - 1 - $offset;

JOB: for ( ; $jobidx >= 0 && $limit > 0; $jobidx-- )
  {
    my $jobid = sprintf( "p%010d", $jobidx );
    my $jobinfo = $self->job($jobid)->info;
    last unless defined $jobinfo;

    foreach my $k ( keys %$matchopts )
    {
      next JOB if ( !exists $jobinfo->{$k} );
      next JOB if ( $matchopts->{$k} ne $jobinfo->{$k} );
    }
    $jobinfo->{jobid} = $jobid;
    push @jobs, $jobinfo;
    $limit--;
  }
  return @jobs;
}

1;

=pod

=head1 NAME

  Pogo::Engine - interact with the pogo backend

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
