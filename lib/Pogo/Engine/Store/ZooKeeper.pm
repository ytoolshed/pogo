package Pogo::Engine::Store::ZooKeeper;

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
use Net::ZooKeeper qw(:node_flags :acls :errors);
use Data::Dumper;

use constant ZK_ACL        => ZOO_OPEN_ACL_UNSAFE;
use constant ZK_SERVERLIST => qw(localhost:2181);
my @ZOO_ERRORS = (
  [ 0,    'ZOK',                      'Everything is OK' ],
  [ -1,   'ZSYSTEMERROR',             'ZSYSTEMERROR' ],
  [ -2,   'ZRUNTIMEINCONSISTENCY',    'A runtime inconsistency was found', ],
  [ -3,   'ZDATAINCONSISTENCY',       'A data inconsistency was found', ],
  [ -4,   'ZCONNECTIONLOSS',          'Connection to the server has been lost', ],
  [ -5,   'ZMARSHALLINGERROR',        'Error while marshalling or unmarshalling data', ],
  [ -6,   'ZUNIMPLEMENTED',           'Operation is unimplemented', ],
  [ -7,   'ZOPERATIONTIMEOUT',        'Operation timeout', ],
  [ -8,   'ZBADARGUMENTS',            'Invalid arguments', ],
  [ -9,   'ZINVALIDSTATE',            'Invalid zhandle state', ],
  [ -100, 'ZAPIERROR',                'ZAPIERROR' ],
  [ -101, 'ZNONODE',                  'Node does not exist' ],
  [ -102, 'ZNOAUTH',                  'Not authenticated' ],
  [ -103, 'ZBADVERSION',              'Version conflict' ],
  [ -108, 'ZNOCHILDRENFOREPHEMERALS', 'Ephemeral nodes may not have children', ],
  [ -110, 'ZNODEEXISTS',              'The node already exists', ],
  [ -111, 'ZNOTEMPTY',                'The node has children', ],
  [ -112, 'ZSESSIONEXPIRED',          'The session has been expired by the server', ],
  [ -113, 'ZINVALIDCALLBACK',         'Invalid callback specified', ],
  [ -114, 'ZINVALIDACL',              'Invalid ACL specified', ],
  [ -115, 'ZAUTHFAILED',              'Client authentication failed', ],
  [ -116, 'ZCLOSING',                 'ZooKeeper is closing', ],
  [ -117, 'ZNOTHING',                 '(not error) no server responses to process', ],
  [ -118, 'ZSESSIONMOVED',            'session moved to another server, so operation is ignored', ],
);

my %ZOO_ERROR_NUMBER = map { $_->[0] => $_->[2] } @ZOO_ERRORS;
my %ZOO_ERROR_NAME   = map { $_->[1] => $_->[0] } @ZOO_ERRORS;

sub new
{
  my ( $class, $opts ) = @_;
  my @serverlist =
    defined $opts->{store_options}->{serverlist}
    ? @{ $opts->{store_options}->{serverlist} }
    : ZK_SERVERLIST;

  my $serverlist = join( ',', @serverlist );
  DEBUG "using serverlist '$serverlist'";

  my $self = { handle => Net::ZooKeeper->new($serverlist), };
  LOGDIE "couldn't init zookeeper: $!" unless defined $self->{handle};

  $self->{handle}->{data_read_len} = 1048576;

  bless $self, $class;

  # this is sorta ugly, but whatever
  foreach my $path (qw{/pogo /pogo/ns /pogo/job /pogo/host /pogo/lock /pogo/stats /pogo/taskq})
  {
    if ( !$self->exists($path) )
    {
      $self->create( $path, '' )
        or LOGDIE "unable to create path '$path': " . $self->get_error;
      DEBUG "created zk path '$path'";
    }
  }

  $self->ping
    or LOGDIE "unable to ping?!: " . $self->get_error;

  return $self;
}

sub _get_children_version
{
  my ( $self, $node ) = @_;
  my $stat = $self->stat;
  if ( $self->{handle}->exists( $node, stat => $stat ) )
  {
    return $stat->{'children_version'};
  }
  return;
}

sub ping
{
  my $self = shift;
  my $testdata = shift || 0xDEADBEEF;

  DEBUG "got here";
  my $node = $self->create( '/pogo/lock/ping', '', flags => ZOO_SEQUENCE | ZOO_EPHEMERAL, )
    or LOGDIE "unable to create ping node: " . $self->get_error;
  DEBUG "got here too";

  $self->set( $node, $testdata ) or LOGDIE "unable to set data: " . $self->get_error;
  my $probe = $self->get($node) or LOGDIE "unable to get data: " . $self->get_error;
  $self->delete($node) or LOGDIE "unable to delete $node: " . $self->get_error;
  LOGDIE "unable to write test data to $node" unless $probe eq $testdata;
  return $probe;
}

sub create
{
  my ( $self, $path, $contents, %opts ) = @_;
  $opts{acl} ||= ZK_ACL;

  my $ret = $self->{handle}->create( $path, $contents, %opts );

  return $ret;
}

sub get_error
{
  my ( $self, @opts ) = @_;
  my $err = $self->{handle}->get_error(@opts);
  return $ZOO_ERROR_NUMBER{$err} || $err;
}

sub exists { return shift->{handle}->exists(@_); }
sub get    { return shift->{handle}->get(@_); }
sub set    { return shift->{handle}->set(@_); }
sub delete { return shift->{handle}->delete(@_); }
sub get_children { return shift->{handle}->get_children(@_); }

1;

