package Pogo::Engine::Store;

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

use strict;
use warnings;

use Time::HiRes qw(sleep);
use Exporter 'import';
use Log::Log4perl qw(:easy);

our @EXPORT_OK = qw(store);

our $store;

sub instance
{
  my ( $class, $opts ) = @_;

  LOGDIE "must define a datastore" unless $opts->{store};

  # so far we only support zookeeper

  if ( $opts->{store} eq 'zookeeper' )
  {
    use Pogo::Engine::Store::ZooKeeper;

    # by default we'll use the same peerlist as everything else
    my $store_opts = $opts->{store_options};
    if ( !exists $store_opts->{serverlist} && exists $opts->{peers} )
    {
      $store_opts->{serverlist} = $opts->{peers};
    }

    # retry a few times here in case zookeeper isn't ready yet.
    for ( my $try = 10; $try > 0; $try-- )
    {
      eval { $store = Pogo::Engine::Store::ZooKeeper->new($store_opts); };
      if ($@)
      {
        ERROR "Couldn't init zookeeper; retrying in $try..";
        sleep 0.2;
        next;
      }
      return $store;
    }
    LOGDIE "Couldn't init zookeeper";
  }
  else
  {
    LOGDIE "invalid storage engine '" . $opts->{store} . "', bye";
  }

  return;
}

sub init
{
  my ( $class, $conf ) = @_;
  return $class->instance($conf);
}

sub store
{
  LOGDIE "not yet initialized" unless defined $store;
  return $store;
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
