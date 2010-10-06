package Pogo::Engine::Store::ZooKeeper;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use Net::ZooKeeper qw(:node_flags :acls :errors);

use constant ZK_ACL => ZOO_OPEN_ACL_UNSAFE;
use constant ZK_SERVERLIST => qw(localhost:2181);

sub new
{
  my ( $class, %args ) = @_;
  my $serverlist = join(',', $args{serverlist} || ZK_SERVERLIST );
  DEBUG "using serverlist '$serverlist'";

  my $self = { handle => Net::ZooKeeper->new( $serverlist ), };
  LOGDIE "couldn't init zookeeper: $!" unless defined $self->{handle};

  $self->{handle}->{data_read_len} = 1048576;

  bless $self, $class;

  # this is sorta ugly, but whatever
  foreach my $path (qw{/pogo /pogo/ns /pogo/job /pogo/host /pogo/lock /pogo/stats /pogo/taskq})
  {
    if ( !$self->exists($path) )
    {
      $self->create( $path, '', acl => ZK_ACL )
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
  my $self     = shift;
  my $testdata = 0xDEADBEEF;

  my $node = $self->create(
    '/pogo/lock/ping', '',
    flags => ZOO_SEQUENCE | ZOO_EPHEMERAL,
    acl   => ZK_ACL,
  ) or LOGDIE "unable to create ping node: " . $self->get_error;

  $self->set( $node, $testdata ) or LOGDIE "unable to set data: " . $self->get_error;
  my $probe = $self->get($node) or LOGDIE "unable to get data: " . $self->get_error;
  $self->delete($node) or LOGDIE "unable to delete $node: " . $self->get_error;
  LOGDIE "unable to write test data to $node" unless $probe eq 0xDEADBEEF;
  return 1;
}

sub exists { return shift->{handle}->exists(@_); };
sub create { return shift->{handle}->create(@_); };
sub get_error { return shift->{handle}->get_error(@_); };
sub get { return shift->{handle}->get(@_); };
sub set { return shift->{handle}->set(@_); };
sub delete { return shift->{handle}->delete(@_); };


1;

