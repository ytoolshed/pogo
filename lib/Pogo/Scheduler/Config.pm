###########################################
package Pogo::Scheduler::Config;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Scheduler::Constraint;
use Pogo::Scheduler::Config::Tag;
use Pogo::Plugin;
use Module::Pluggable;
use Data::Dumper;
use YAML qw( Load LoadFile );
use base qw(Pogo::Object::Event);

use Pogo::Util qw( make_accessor id_gen struct_traverse );
__PACKAGE__->make_accessor( $_ ) for qw( );

use overload ( 'fallback' => 1, '""' => 'as_string' );

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        cfg  => {},
        tags => {},
        %options,
    };

    $self->{ external_tag_resolver } = 
        Pogo::Plugin->load('TagExternal', { required_methods => [ 'members' ] } );

    bless $self, $class;
}

###########################################
sub load {
###########################################
    my ( $self, $yaml ) = @_;

    $self->{ cfg } = Load( $yaml );
    $self->parse();
}

###########################################
sub load_file {
###########################################
    my ( $self, $yaml_file ) = @_;

    $self->{ cfg } = LoadFile( $yaml_file );
    $self->parse();
}

###########################################
sub tag_add {
###########################################
    my ( $self, $path ) = @_;

    if( !exists $self->{ tags }->{ $path } ) {
        $self->{ tags }->{ $path } = 
          Pogo::Scheduler::Config::Tag->new(
            name => $path );
    }

    return $self->{ tags }->{ $path };
}

###########################################
sub dot_path_climb {
###########################################
    my ( $self, $path, $cb ) = @_;

    # on "foo.bar.baz", call the callback on "foo.bar", and "foo".

    my @parts = split /\./, $path;

    pop @parts;

    while( @parts ) {
        $cb->( $self, join( ".", @parts ) );
        pop @parts;
    }
}

###########################################
sub parse {
###########################################
    my ( $self ) = @_;

    # Turn
    # 
    # foo: 
    #   bar:
    #     - host1
    # baz:
    #     - host2
    # 
    # into
    # 
    # foo->host1,host2
    # foo.bar->host1
    # foo.baz->host1

    Pogo::Util::struct_traverse(
        $self->{ cfg }->{ tag },
        {   leaf => sub {
                my ( $node, $path ) = @_;

                my $dot_path = join '.', @$path;

                my $tag = $self->tag_add( $dot_path );

                $tag->member_add( $node );

                my $child = $tag;

                $self->dot_path_climb( $dot_path, sub {
                    my( $c, $path ) = @_;

                    my $tag = $self->tag_add( $path );
                    $tag->child_add( $child );
                } );
            }
        }
    );
}

###########################################
sub tags {
###########################################
    my ( $self ) = @_;

    return [ keys %{ $self->{ tags } } ];
}

###########################################
sub members {
###########################################
    my ( $self, $tag, $cb ) = @_;

    if( !exists $self->{ tags }->{ $tag } ) {
          # tag doesn't exist. Could this be a external tag reference?
        my( $plugin_short, @params ) = split ' ', $tag;
        if( @params ) {
            return $self->{ external_tag_resolver }->members( 
                $plugin_short, @params, ($cb ? $cb : ()) );
        }

        return ();
    }

    return $self->{ tags }->{ $tag }->members( $tag, ($cb ? $cb : ()) );
}

###########################################
sub as_string {
###########################################
    my ( $self ) = @_;

    local $Data::Dumper::Indent;
    $Data::Dumper::Indent = 0;
    return Dumper( $self->{ cfg } );
}

1;

__END__

=head1 NAME

Pogo::Scheduler::Config - Pogo scheduler configuration handling

=head1 SYNOPSIS

    use Pogo::Scheduler::Config;
    
    my $slot = Pogo::Scheduler::Config->new();
    
=head1 DESCRIPTION

    use Pogo::Scheduler::Config;

    my $cfg = Pogo::Scheduler::Config->new();
    $cfg->load( <<'EOT' );
      tag:
         colo.usa
           - host1
         colo.mexico
           - host2
    EOT

    my @all = $cfg->members( "colo" );           # host1, host2
    my @mexico = $cfg->members( "colo.mexico" ); # host2

=head2 METHODS

=over 4

=item C< load( $yaml ) >

Load a scheduler configuration from a YAML string.

=item C< load_file( $yaml_file ) >

Load a YAML scheduler configuration from a YAML file.

=item C< members( $tag, [ $cb ] ) >

Return all members of the tag. Optionally, use the provided callback
instead of returning the results.

=back

=head2 External Tag Resolvers

If C<members()> cannot resolve a tag, it tries to find a plugin in order
the members of the tag.

For a tag to be interpreted as external, it needs to be written in the format

    "MyPlugin param-1 param-2 ..."

This will look for a plugin named C<MyPlugin.pm> in the
C<Pogo::Plugin::TagExternal> directory, 
instantiate it and call its C<members()> method with the specified parameters.

=head1 LICENSE

Copyright (c) 2010-2012 Yahoo! Inc. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
imitations under the License.

=head1 AUTHORS

Mike Schilli <m@perlmeister.com>
Ian Bettinger <ibettinger@yahoo.com>

Many thanks to the following folks for implementing the
original version of Pogo: 

Andrew Sloane <andy@a1k0n.net>, 
Michael Fischer <michael+pogo@dynamine.net>,
Nicholas Harteau <nrh@hep.cat>,
Nick Purvis <nep@noisetu.be>,
Robert Phan <robert.phan@gmail.com>,
Srini Singanallur <ssingan@yahoo.com>,
Yogesh Natarajan <yogesh_ny@yahoo.co.in>

