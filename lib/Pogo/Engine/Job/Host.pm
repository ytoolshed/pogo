package Pogo::Engine::Job::Host;

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

use JSON qw(encode_json decode_json);
use Log::Log4perl qw(:easy);
use Pogo::Engine::Store qw(store);

sub new
{
  my ( $class, $job, $hostname, $defstate ) = @_;

  my $self = {
    name => $hostname,
    path => $job->{path} . "/host/$hostname",
  };

  bless $self, $class;

  if ( !store->exists( $self->path ) )
  {
    if ( !defined $defstate )
    {
      LOGCONFESS "No such host $hostname in job " . $job->id;
    }

    # state is cached here, host objects are recreated on every request
    my $state = ( $defstate || 'waiting' ) . $;;
    store->create( $self->path, $state )
      or LOGDIE "error creating $self->{path}: " . store->get_error_name();

  }

  return $self;
}

sub _get
{
  my ( $self, $k ) = @_;
  return store->get( $self->path . '/' . $k );
}

sub _set
{
  my ( $self, $k, $v ) = @_;
  my $node = $self->path . '/' . $k;
  if ( !store->create( $node, $v ) )
  {
    if ( store->exists($node) )
    {
      store->set( $node, $v )
        or ERROR "Couldn't set $node: " . store->get_error_name;
    }
    else
    {
      LOGDIE "error creating $node: " . store->get_error_name;
    }
  }
}

sub add_outputurl
{
  my ( $self, $url ) = @_;
  my $old;
  eval { $old = decode_json( $self->_get('_output') ); };
  if ( defined $old )
  {
    push @$old, $url;
  }
  else
  {
    $old = [$url];
  }
  return $self->_set( '_output', encode_json($old) );
}

sub outputurls
{
  my $self = shift;
  return decode_json( $self->_get('_output') );
}

sub set_hostinfo
{
  my ( $self, $info ) = @_;
  $self->{info} = $info;
  $info = encode_json($info);
  return $self->_set( '_info', $info );
}

sub info
{
  my $self = shift;
  if ( !exists $self->{info} )
  {
    my $hinfo = $self->_get('_info');
    if ( !defined $hinfo )
    {
      WARN "no hostinfo found for " . $self->name;
      return;
    }
    $self->{info} = decode_json($hinfo);
  }

  return $self->{info};
}

sub state
{
  my $self = shift;
  my ( $state, $extstate ) = split /$;/, store->get( $self->path );
  return wantarray ? ( $state, $extstate ) : $state;    # <-- ugh
}

sub _is_finished
{
  my $state = shift;
  return (
         $state eq 'finished'
      or $state eq 'unreachable'
      or $state eq 'failed'
      or $state eq 'skipped'
      or $state eq 'halted'
      or $state eq 'deadlocked'
  ) ? 1 : 0;
}

sub _is_failed
{
  my $state = shift;
  return (
         $state eq 'unreachable'
      or $state eq 'offline'
      or $state eq 'failed'
      or $state eq 'deadlocked'
  ) ? 1 : 0;
}

sub _is_running
{
  my $state = shift;
  return ( $state eq 'ready' or $state eq 'running' )
    ? 1
    : 0;
}

sub _is_runnable
{
  my $state = shift;
  return ( $state eq 'waiting' or $state eq 'deadlocked' ) ? 1 : 0;
}

# Monitor state transitions and keep tally of finished hosts as an optimization
# (otherwise we have to scan the entire host list to figure out when a job is
# done)
sub set_state
{
  my ( $self, $state, $ext, @extrastate ) = @_;
  my ( $prevstate, $prevext ) = $self->state;

  return if ( $prevstate eq $state and $prevext eq $ext and !@extrastate );

  store->set( $self->{path}, $state . $; . $ext );

  return 1;
}

sub is_finished { return _is_finished( $_[0]->state ) }
sub is_runnable { return _is_runnable( $_[0]->state ) }
sub is_running  { return _is_running( $_[0]->state ) }
sub is_failed   { return _is_failed( $_[0]->state ) }

sub job  { return $_[0]->{job}; }
sub name { return $_[0]->{name}; }
sub path { return $_[0]->{path}; }

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
