package Pogo::Engine::Namespace::Slot;

# Copyright (c) 2010 Yahoo! Inc, all rights reserved.
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

use Log::Log4perl qw(:easy);
use Pogo::Engine::Store qw(store);

sub new
{
  my ( $class, $ns, $app, $envk, $envv ) = @_;
  my $self = {
    app  => $app,
    envk => $envk,
    envv => $envv,
    name => sprintf( '%s %s %s', $envk, $envv, $app ),
    id   => sprintf( '%s_%s_%s', $app, $envk, $envv ),
    path => sprintf( '%s/env/%s_%s_%s', $ns->{path}, $app, $envk, $envv ),
    maxdown => undef,    # this gets initialized by Namespace.pm
  };

  return bless $self, $class;
}

sub name
{
  return $_[0]->{name};
}

sub id
{
  return $_[0]->{id};
}

# unclear on the magic in job/host_ignore
sub nlocked
{
  my ( $self, $job_ignore, $host_ignore ) = @_;
  my $n = scalar store->get_children( $self->{path} );
  return 0 if ( !defined $n );
  if ( defined $host_ignore )
  {
    $n-- if store->exists( $self->{path} . '/' . $job_ignore->id . '_' . $host_ignore );
  }
  return $n;
}

sub is_full
{
  my ( $self, $job_ignore, $host_ignore ) = @_;
  return $self->nlocked( $job_ignore, $host_ignore ) >= $self->{maxdown};
}

sub reserve
{
  my ( $self, $job, $hostname ) = @_;
  my $lockname = $job->id . '_' . $hostname;
  my $path     = $self->{path} . '/' . $lockname;

  # we're going to ASSume if this fails it's because $path DNE
  if ( !store->create( $path, '' ) )
  {
    LOGDIE "unable to create environment slot '$path': " . store->get_error_name;
  }
}

sub unreserve
{
  my ( $self, $job, $hostname ) = @_;
  my $lockname = $job->id . '_' . $hostname;
  my $path     = $self->{path} . '/' . $lockname;

  if ( !store->delete($path) )
  {
    ERROR "something amiss? couldn't unreserve '$path':" . store->get_error_name;
  }

  # will only succeed when there is nothing else reserved but that's what we
  # want; otherwise we need to do a more expensive get_children call here
  return store->delete( $self->{path} );
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
