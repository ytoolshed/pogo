###########################################
package Pogo::Scheduler::Config::Tag;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Data::Dumper;

use Pogo::Util qw( make_accessor );
__PACKAGE__->make_accessor( $_ ) for qw( );

use overload ( 'fallback' => 1, '""' => 'as_string' );

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        children => [],
        members  => [],
        %options,
    };

    bless $self, $class;
}

###########################################
sub member_add {
###########################################
    my ( $self, @members ) = @_;

    push @{ $self->{ members } }, @members;
}

###########################################
sub child_add {
###########################################
    my ( $self, @children ) = @_;

    push @{ $self->{ children } }, @children;
}

###########################################
sub members {
###########################################
    my ( $self ) = @_;

    my @members = ();

    push @members, @{ $self->{ members } };

    for my $child ( @{ $self->{ children } } ) {
        push @members, $child->members();
    }

    return @members;
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

Pogo::Scheduler::Config::Tag - Group hosts using tags

=head1 SYNOPSIS

    use Pogo::Scheduler::Config::Tag;
    
    my $tag = Pogo::Scheduler::Config::Tag->new( name => "foo" );
    $tag->member_add( "host1" );

    my $subtag = Pogo::Scheduler::Config::Tag->new( "foochild" );
    $subtag->member_add( "host2" );

    $tag->child_add( $subtag );

    my @members = $tag->members( "foo" );   # => host1, host2

=head1 DESCRIPTION

Pogo::Scheduler::Config::Tag groups hosts by tags. Tags contain members
and other tag objects.

=head2 METHODS

=over 4

=item C<member_add()>

Add a host to a tag.

=item C<child_add()>

Add a child tag to a tag.

=item C<members()>

Return a list of all members of a tag and its child tags.

=back

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

