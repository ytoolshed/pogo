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

use Pogo::Engine::Job;
use Pogo::Engine::Namespace;

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

  LOGDIE "must define a datastore" unless $opts->{store};

  if ( $opts->{store} eq 'zookeeper' )
  {
    use Pogo::Engine::Store::ZooKeeper;
    $instance->{store} = Pogo::Engine::Store::ZooKeeper->new();
  }
  else
  {
    LOGDIE "invalid storage engine '" . $opts->{store} . "', bye";
  }

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
