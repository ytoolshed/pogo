# A mock for Pogo/Engine/Store.pm that works without zookeeper
package PogoMockStore;
use Test::MockObject;

  # This is so that if we type
  #    use PogoMockStore;
  # in our test scripts, Pogo::Engine::Store::store() will be overridden
  # to return the mock store instead. Also, it won't load Pogo::Engine::Store
  # at all and its Zookeeper dependencies, but work standalone.
sub import {
    my $mock = Test::MockObject->new();
    my $pms = PogoMockStore->new();
    $mock->fake_module(
        'Pogo::Engine::Store',
        store => sub { return $pms; },
        init  => sub { return 1; },
    );
}

use Log::Log4perl qw(:easy);
use JSON qw(encode_json);
use File::Basename;
use Data::Dumper;

sub new
{
  my ( $class, %options ) = @_;
  my $self = { 
      store => {},
      %options 
  };
  bless $self, $class;
}

sub create_sequence { 
    my( $self, $key ) = @_;

    my $dir = dirname $key;

    DEBUG "mockstore: create_sequence @_";
    my $href = path2mhash( $dir, $self->{store}, 1 );

    my $max_seq = 0;

    my $base = basename $key;

    for my $key ( sort keys %href ) {
        if( $key =~ /^$base(\d+)$/ ) {
            if( $1 > $max_seq ) {
                $max_seq = $1;
            }
        }
    }

    my $newkey = sprintf "$base%06d", $max_seq;
    $href->{ $newkey } = undef;

    DEBUG "mockstore: create_sequence created new key $newkey in $dir@_ ";
    DEBUG "mockstore: ", $self->_dump();

    return "$dir/$newkey";
}

sub init { 
    DEBUG "mockstore: init @_ (stubbed)";
    return 1; 
}

sub store { 
    DEBUG "mockstore: store @_ (stubbed)";
    return 1; 
}

sub lock {
    DEBUG "mockstore: lock @_ (stubbed)";
    return 1; 
}

sub _lock_write {
    DEBUG "mockstore: _lock_write @_ (stubbed)";
    return 1; 
}

sub unlock {
    DEBUG "mockstore: unlock @_ (stubbed)";
    return 1; 
}

sub create { 
    my( $self, $key ) = @_;
    DEBUG "mockstore: create @_";
    path2mhash( $key, $self->{store}, 1 );

    return 1; 
}

sub exists { 
    my( $self, $key ) = @_;
    DEBUG "mockstore: exists @_";
    return path2mhash( $key, $self->{store} );
}

sub delete_r { 
    my( $self, $key ) = @_;
    DEBUG "mockstore: delete_r @_";

    my $dir = dirname( $key );

    my $dref = path2mhash( $dir, $self->{store} );

    if( defined $dref ) {
        delete $dref->{ basename $key };
        return 1;
    }

    return undef; 
}

sub set
{
  my ( $self, $key, $val ) = @_;

  my $base = basename($key);
  my $dir  = dirname($key);

  $val =~ s/^"(.*)"$/$1/;

  path2mhash( $dir, $self->{store}, 1 )->{$base} = $val;

  DEBUG "set($key, $val): ", defined $val ? $val : "[undef]";

  return 1;
}

sub get
{
  my ( $self, $key ) = @_;

  my $base = basename($key);
  my $dir  = dirname($key);

  my $val = undef;

  if(defined path2mhash( $dir, $self->{store} ) ) {
      $val = path2mhash( $dir, $self->{store} )->{$base};
  }

  $val = { $key => '[undef]' } unless defined $val;

  DEBUG "get($key): ", Dumper($val);
  return encode_json($val);
}

sub get_children
{
  my ( $self, $key ) = @_;

  my $ref = path2mhash( $key, $self->{store} );

  if( !defined $ref ) {
      return undef;
  }
  my @children = keys %{ $ref };
  DEBUG "get_children($key): @children";
  return @children;
}

# helper to transform "a/b/c" to $href->{a}->{b}->{c}
sub path2mhash
{
  my ( $path, $href, $create ) = @_;

  my $p = $href;

  for my $part ( split m#/#, $path )
  {
    next if !length($part);
    if ( !exists $p->{$part} )
    {
      if( !$create ) {
          return undef;
      }
      $p->{$part} = {};
    }
    $p = $p->{$part};
  }

  return $p;
}

sub _dump { 
  my ( $self, $prefix, $subtree ) = @_;

  my $so_far  = "";

  $prefix  = "" unless defined $prefix;
  $subtree = $self->{store} unless defined $subtree;

  # DEBUG "pref=$prefix so_far=$so_far";

  for my $key ( keys %$subtree ) {

      my $val = $subtree->{ $key };

      if( ref($val) eq "" ) {
          $so_far .= "$prefix/$key\n";
      } else {
          $so_far .= $self->_dump( "$prefix/$key", $val );
      }
  }

  return $so_far;
}

1;

__END__

=head1 NAME

PogoMockStore - A Mock for Pogo::Engine::Store without ZooKeeper

=head1 SYNOPSIS

    use PogoMockStore;
    use Test::MockObject;

    my $store = PogoMockStore->new();
    my $slot  = Test::MockObject->new();

    my $ns = Pogo::Engine::Namespace->new(
      store    => $store,
      get_slot => $slot,
      nsname   => "wonk",
    );

=head1 DESCRIPTION

Works similarily to Pogo::Engine::Store.

=head1 AUTHOR

2011, Mike Schilli <github@perlmeister.com>
