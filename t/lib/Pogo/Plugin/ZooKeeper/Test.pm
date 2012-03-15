###########################################
package Pogo::Plugin::ZooKeeper::Test;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use File::Basename;
use Pogo::Util qw(make_accessor);
use AnyEvent;
require Exporter;
our @ISA = qw( Exporter Pogo::Object::Event );
our @EXPORT_OK = qw( ZOK ZINVALIDSTATE ZCONNECTIONLOSS );

__PACKAGE__->make_accessor( "ZOK" );
__PACKAGE__->make_accessor( "ZINVALIDSTATE" );
__PACKAGE__->make_accessor( "ZCONNECTIONLOSS" );
__PACKAGE__->ZOK(0);
__PACKAGE__->ZINVALIDSTATE(-9);
__PACKAGE__->ZCONNECTIONLOSS(-4);

###########################################
sub new {
###########################################
    my($class, $host, %options) = @_;

    my $self = {
        name      => undef,
        path      => undef,
        content   => undef,
        children  => {},
        connector => undef,
        %options
    };

    $self->{name} = "ROOT" unless defined $self->{name};
    $self->{path} = "/" unless defined $self->{path};
    DEBUG "zkm: new node '$self->{path}'";

    $self->{ connector } = AnyEvent->timer(
        after => 0,
        cb    => sub { $self->event( "zk_connect_ok" );
        },
    );
    bless $self, $class;
    return $self;
}

###########################################
sub traverse {
###########################################
    my($self, $callback, $args) = @_;

    $callback->( $self, $args );

    for my $childname ( $self->get_children() ) {
        $self->{children}->{$childname}->traverse( $callback, $args );
    }
}

###########################################
sub _dump {
###########################################
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

  # dumps out emtpy nodes as well as nodes with content
###########################################
sub _dump_full_structure {
###########################################
    my($self) = @_;

    my $string = "";

    $self->traverse( sub {
        my( $node ) = @_;
        $string .= "$node->{path}";
        if( defined $node->{content} ) {
            $string .= ": [$node->{content}]";
        }
        $string .= "\n";
    });

    return $string;
}

###########################################
sub exists {
###########################################
    my($self, $path) = @_;

    my $exists = $self->path( $path, 0 );

    DEBUG "zkm: $path ", ($exists ? "exists" : "doesn't exist");
    return $exists;
}

###########################################
sub create {
###########################################
    my($self, $path, $value) = @_;

    DEBUG "zkm: create '$path'";

    if( defined $value ) {
        $self->set( $path, $value );
    }

    return $self->path( $path, 1 );
}

###########################################
sub path {
###########################################
    my($self, $path, $create) = @_;

    my $node        = $self;
    my $path_so_far = "";

    for my $part ( split m#/#, $path ) {
        next if !length($part);
        $path_so_far .= "/$part";

        if( !exists $node->{children}->{ $part } ) {
            if( $create ) {
                 $node->{children}->{ $part } = 
                     __PACKAGE__->new( 
                         "bogushost",
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

###########################################
sub get_error {
###########################################
    return 0;
}

###########################################
sub delete {
###########################################
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

###########################################
sub set {
###########################################
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

###########################################
sub get {
###########################################
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

###########################################
sub delete_r { 
###########################################
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

###########################################
sub get_children
###########################################
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

###########################################
sub create_sequence { 
###########################################
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

###########################################
sub init { 
###########################################
    DEBUG "mockstore: init @_ (stubbed)";
    return 1; 
}

###########################################
sub store { 
###########################################
    DEBUG "mockstore: store @_ (stubbed)";
    return 1; 
}

###########################################
sub lock {
###########################################
    DEBUG "mockstore: lock @_ (stubbed)";
    return 1; 
}

###########################################
sub _lock_write {
###########################################
    DEBUG "mockstore: _lock_write @_ (stubbed)";
    return 1; 
}

###########################################
sub unlock {
###########################################
    DEBUG "mockstore: unlock @_ (stubbed)";
    return 1; 
}

###########################################
sub priority {
###########################################
      # For plugin framework
    return 10;
}

1;

__END__

=head1 NAME

Pogo::Plugin::ZooKeeper::Test - In-memory plugin emulating ZK for testing

=head1 SYNOPSIS

    use Pogo::Plugin::ZooKeeper::Test;

=head1 DESCRIPTION

Offers a (almost complete) ZooKeeper mock for testing purposes.

=head1 AUTHOR

2011, Mike Schilli <github@perlmeister.com>
