# A mock for Pogo/Engine/Store.pm that works without zookeeper
package Net::ZooKeeper::Mock::Node;
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use File::Basename;

sub new {
    my($class, %options) = @_;

    my $self = {
        name     => undef,
        path     => undef,
        content  => undef,
        children => {},
        %options
    };

    $self->{name} = "ROOT" unless defined $self->{name};
    $self->{path} = "/" unless defined $self->{path};
    DEBUG "zkm: new node '$self->{path}'";

    bless $self, $class;
    return $self;
}

sub traverse {
    my($self, $callback, $args) = @_;

    $callback->( $self, $args );

    for my $childname ( $self->get_children() ) {
        $self->{children}->{$childname}->traverse( $callback, $args );
    }
}

sub _dump {
    my($self) = @_;

    my $string = "";

    $self->traverse( sub {
        my( $node ) = @_;
        if( !defined $node->{content} ) {
                  # Don't print empty path parts
            return;
        }
        $string .= "$node->{path}";
        $string .= ": [$node->{content}]";
        $string .= "\n";
    });

    return $string;
}

sub exists {
    my($self, $path) = @_;

    my $exists = $self->path( $path, 0 );

    DEBUG "zkm: $path ", ($exists ? "exists" : "doesn't exist");
    return $exists;
}

sub create {
    my($self, $path, $value) = @_;

    DEBUG "zkm: create '$path'";

    if( defined $value ) {
        $self->set( $path, $value );
    }

    return $self->path( $path, 1 );
}

sub path {
    my($self, $path, $create) = @_;

    my $node        = $self;
    my $path_so_far = "";

    for my $part ( split m#/#, $path ) {
        next if !length($part);
        $path_so_far .= "/$part";

        if( !exists $node->{children}->{ $part } ) {
            if( $create ) {
                 $node->{children}->{ $part } = 
                     Net::ZooKeeper::Mock::Node->new( 
                         name => $part,
                         path => $path_so_far );
            } else {
                return undef;
            }
        }
        $node = $node->{children}->{ $part };
    }

    return $node;
}

sub delete {
    my($self, $path) = @_;

    my $dir  = dirname $path;
    my $base = basename $path;

    my $parent = $self->exists( $dir );

    if(! defined $parent) {
        return undef;
    }

    delete $parent->{children}->{$base};

    1;
}

sub set {
    my($self, $path, $val) = @_;

    my $disp_val = defined $val ? $val : "[undef]";
    DEBUG "zkm: set '$path'='$disp_val'";

      # Make sure the parent dir exists
    my $dir = dirname $path;
    if( !defined $self->exists( $dir ) ) {
        return undef;
    }

      # Create the entry if it doesn't exist yet
    my $node = $self->create( $path );

    if( !defined $node ) {
        return undef;
    }

    $val = defined $val ? $val : "";
    $node->{content} = "$val";
}

sub get {
    my( $self, $path ) = @_;

    my $node = $self->exists( $path );

    if( !defined $node ) {
        return undef;
    }

    my $content = $node->{content};
    my $disp_content = defined $content ? $content : "[undef]";
    DEBUG "zkm: get '$path'='$disp_content'";

    return $content;
}

sub delete_r { 
    my( $self, $path ) = @_;

    my $dir  = dirname( $path );
    my $base = basename( $path );

    my $node = $self->exists( $dir );

    if(! defined $node ) {
        return undef;
    }

    if(! exists $node->{children}->{ $base } ) {
        return undef;
    }

    delete $node->{children}->{ $base };

    return 1;
}

sub get_children
{
    my ( $self, $path ) = @_;

    my $node = $self;

    if( defined $path ) {
        $node = $self->exists( $path );

        if(! defined $node ) {
            return undef;
        }
    }

    return sort keys %{ $node->{children} };
}

sub create_sequence { 
    my( $self, $path ) = @_;

    my $dir  = dirname $path;
    my $base = basename $path;

    DEBUG "zkm: create_sequence $path";

    my $node = $self->create( $dir );

    if(! defined $node ) {
        return undef;
    }

    my $max_seq = 0;

    for my $childname ( $node->get_children() ) {
        if( $childname =~ /^$base(\d+)$/ ) {
            if( $1 >= $max_seq ) {
                $max_seq = $1;
            }
        }
    }

    my $newkey = sprintf "$base%06d", $max_seq + 1;

    if( ! $self->create( "$dir/$newkey" ) ) {
        return undef;
    }

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

package PogoMockStore;
use Test::MockObject;
use base 'Net::ZooKeeper::Mock::Node';

  # This is so that if we type
  #    use PogoMockStore;
  # in our test scripts, Pogo::Engine::Store::store() will be overridden
  # to return the mock store instead. Also, it won't load Pogo::Engine::Store
  # at all and its Zookeeper dependencies, but work standalone.
my $mock = Test::MockObject->new();
my $pms = Net::ZooKeeper::Mock::Node->new();
$mock->fake_module(
    'Pogo::Engine::Store',
    store => sub { return $pms; }, # singleton used all over the place
    init  => sub { return 1; },
      # no fancy Exporter export_ok, just import it
    import => sub {
        my $callerpkg = caller();
        no strict qw(refs);
        *{"$callerpkg\::store"} = *{"Pogo::Engine::Store\::store"};
    }
);

1;

__END__

=head1 NAME

PogoMockStore - A Mock for Pogo::Engine::Store without ZooKeeper

=head1 SYNOPSIS

      # in the test script
    use PogoMockStore;

      # in the module using Pogo::Engine::Store 
    use Pogo::Engine::Store qw(store);

=head1 DESCRIPTION

Pretends to have loaded Pogo::Engine::Store already (so doesn't Barf if
Net::ZooKeeper isn't installed, which the real Pogo::Engine::Store requires),
overwrites the exported store() method in the target module, and offers a
(almost complete) ZooKeeper mock behind the object returned by store().

=head1 AUTHOR

2011, Mike Schilli <github@perlmeister.com>
