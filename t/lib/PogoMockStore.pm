# A mock for Pogo/Engine/Store.pm that works without zookeeper
package PogoMockStore;

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

sub store { return 1; }

sub create { return 1; }

sub exists { return 1; }

sub delete_r { return 1; }

sub set
{
  my ( $self, $key, $val ) = @_;

  my $base = basename($key);
  my $dir  = dirname($key);

  path2mhash( $dir, $self->{store} )->{$base} = $val;

  DEBUG "set($key, $val): ", defined $val ? $val : "[undef]";
  DEBUG "store: ", Dumper( $self->{store} );

  return 1;
}

sub get
{
  my ( $self, $key ) = @_;

  my $base = basename($key);
  my $dir  = dirname($key);

  my $val = path2mhash( $dir, $self->{store} )->{$base};
  $val = '[undef]' unless defined $val;
  DEBUG "get($key): ", Dumper($val);
  return encode_json($val);
}

sub get_children
{
  my ( $self, $key ) = @_;

  my @children = keys %{ path2mhash( $key, $self->{store} ) };
  DEBUG "get_children($key): @children";
  return @children;
}

# helper to transform "a/b/c" to $href->{a}->{b}->{c}
sub path2mhash
{
  my ( $path, $href ) = @_;

  my $p = $href;

  for my $part ( split m#/#, $path )
  {
    next if !length($part);
    if ( !exists $p->{$part} )
    {
      $p->{$part} = {};
    }
    $p = $p->{$part};
  }

  return $p;
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
