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

use Data::Dumper;

use common::sense;

use Log::Log4perl qw(:easy);
use Net::ZooKeeper qw(:node_flags :acls :errors);
use Time::HiRes qw(sleep);

use constant ZK_ACL        => ZOO_OPEN_ACL_UNSAFE;
use constant ZK_SERVERLIST => qw(localhost);
use constant ZK_PORT       => 2181;

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
    defined $opts->{serverlist}
    ? @{ $opts->{serverlist} }
    : ZK_SERVERLIST;

  # build serverlist;
  my $serverport = $opts->{port} || ZK_PORT;
  my $serverlist = pop(@serverlist) . ":$serverport";
  map { $serverlist .= ",$_:$serverport" } @serverlist;

  DEBUG "serverlist=$serverlist";

  my $self = { handle => Net::ZooKeeper->new($serverlist), };
  LOGDIE "couldn't init zookeeper: $!" unless defined $self->{handle}->{session_id};
  bless $self, $class;

  INFO "Connected to '$serverlist'";
  DEBUG sprintf( "Session timeout is %.2f seconds.\n", $self->{handle}->{session_timeout} / 1000 );

  $self->{handle}->{data_read_len} = 1048576;

  # this is sorta ugly, but whatever
  foreach my $path (qw{/pogo /pogo/ns /pogo/job /pogo/host /pogo/lock /pogo/stats /pogo/taskq})
  {
    if ( !$self->exists($path) )
    {
      $self->create( $path, '' )
        or LOGDIE "unable to create path '$path': " . $self->get_error_name;
      DEBUG "created zk path '$path'";
    }
  }

  $self->ping
    or LOGDIE "unable to ping?!: " . $self->get_error;

  DEBUG $self->get_error_name;

  return $self;
}

sub get_children_version
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

  my $node = $self->create( '/pogo/lock/ping', '', flags => ZOO_SEQUENCE | ZOO_EPHEMERAL, )
    or LOGDIE "unable to create ping node: " . $self->get_error_name;

  $self->set( $node, $testdata ) or LOGDIE "unable to set data: " . $self->get_error_name;
  my $probe = $self->get($node) or LOGDIE "unable to get data: " . $self->get_error_name;
  $self->delete($node) or LOGDIE "unable to delete $node: " . $self->get_error_name;
  LOGDIE "unable to write test data to $node" unless $probe eq $testdata;
  return $probe;
}

sub create
{
  my ( $self, $path, $contents, %opts ) = @_;
  $opts{acl} ||= ZK_ACL;
  my $ret;
  eval { $ret = $self->{handle}->create( $path, $contents, %opts ); };
  return $ret;
}

sub create_ephemeral
{
  return shift->create( @_, flags => ZOO_EPHEMERAL );
}

sub create_sequence
{
  return shift->create( @_, flags => ZOO_SEQUENCE );
}

sub get_error_name
{
  my ( $self, @opts ) = @_;
  my $err = $self->{handle}->get_error(@opts);
  return $ZOO_ERROR_NUMBER{$err} || $err;
}

sub delete_r
{
  my ( $self, $path ) = @_;
  foreach my $node ( $self->get_children($path) )
  {
    $self->delete_r("$path/$node");
  }
  if ( !$self->delete($path) )
  {
    WARN "unable to remove '$path': " . $self->get_error;
    return 0;
  }
  TRACE "removed '$path'";
  return 1;
}

sub _lock_wait
{
  my ( $self, $lockpath, $pattern, $timeout ) = @_;
  LOGDIE "$lockpath has no sequence number?" if ( !$lockpath =~ m/^(.*)\/\S+-(\d+)$/ );
  my $path  = $1;
  my $seqno = $2;

  while (1)
  {
    my ( $path_to_wait, $seq_to_wait );
    {
      foreach my $child ( $self->get_children($path) )
      {
        if ( $child =~ /$pattern(\d+)$/ )
        {
          my $pseq = $1;
          if ( $pseq < $seqno && ( !defined $seq_to_wait || $pseq > $seq_to_wait ) )
          {
            $path_to_wait = $child;
            $seq_to_wait  = $pseq;
          }
        }
      }
    }

    # If we don't have to wait for anything, we are done
    if ( !defined $path_to_wait )
    {
      return $lockpath;
    }

    my $watch = $self->{handle}->watch( 'timeout' => $timeout );
    if ( $self->exists( $path_to_wait, watch => $watch ) )
    {

      # if exists() returns true, wait for a notification for the pathname
      # from the previous step
      if ( !$watch->wait() )
      {

        # timed out
        $self->delete($lockpath);
        return;
      }
    }
  }
}

sub _lock_read
{
  my ( $self, $path, $source, $timeout ) = @_;
  my $lockpath = $self->create( $path . '/read-', $source, flags => ZOO_EPHEMERAL | ZOO_SEQUENCE, );
  LOGDIE "unable to create read lock: " . $self->get_error_name()
    unless defined $lockpath;

  return $self->_lock_wait( $lockpath, 'write-', $timeout );
}

sub _lock_write
{
  my ( $self, $path, $source, $timeout ) = @_;
  my $lockpath =
    $self->create( $path . '/write-', $source, flags => ZOO_EPHEMERAL | ZOO_SEQUENCE, );
  LOGDIE "unable to create write lock: " . $self->get_error_name()
    unless defined $lockpath;

  return $self->_lock_wait( $lockpath, '-', $timeout );
}

sub lock
{
  my ( $self, $source ) = @_;
  LOGDIE "lock needs a source"
    unless defined $source;
  $self->_lock_write( '/pogo/lock', $source, 60000 )
    or LOGDIE "timed out locking globally for $source\n";
}

sub unlock
{
  my ( $self, $lock ) = @_;
  return $self->delete($lock);
}

sub stat         { return shift->{handle}->stat(@_); }
sub exists       { return shift->{handle}->exists(@_); }
sub get          { return shift->{handle}->get(@_); }
sub set          { return shift->{handle}->set(@_); }
sub delete       { return shift->{handle}->delete(@_); }
sub get_children { return shift->{handle}->get_children(@_); }
sub get_error    { return shift->{handle}->get_error(@_); }

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
