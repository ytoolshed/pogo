###########################################
package Pogo::Scheduler::Config::TagExternal;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Module::Pluggable require => 1;

use overload ( 'fallback' => 1, '""' => 'as_string' );

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        %options,
    };

    bless $self, $class;

    for my $plugin ( $self->plugins() ) {
        ( my $short = $plugin ) =~ s/.*:://;
        $self->{ plugins }->{ $short } = $plugin;
    }

    return $self;
}

###########################################
sub has_plugin {
###########################################
    my ( $self, $short ) = @_;

    if( exists $self->{ plugins }->{ $short } ) {
        return 1;
    }

    DEBUG "Plugin $short not found";
    return 0;
}

###########################################
sub members {
###########################################
    my ( $self, $plugin_short, @params ) = @_;

    return undef if !$self->has_plugin( $plugin_short );

    if( exists $self->{ plugins }->{ $plugin_short } ) {
        return $self->{ plugins }->{ $plugin_short }->members( @params );
    }
}

###########################################
sub as_string {
###########################################
    my ( $self ) = @_;

    return "$self with plugins " . join( ", ", keys %{ $self->{ plugins } } );
}

1;

__END__

=head1 NAME

Pogo::Scheduler::Config::TagExternal - External tag resolver with plugins

=head1 SYNOPSIS

    use Pogo::Scheduler::Config::TagExternal;
    
    my $resolver = Pogo::Scheduler::Config::TagExternal->new();
    my @result = $resolver->members( "Example", "testtag" );

=head1 DESCRIPTION

External tag resolver for Pogo configurations. See 
C<Pogo::Scheduler::Classic> for details on how configuration files use it.

=head2 METHODS

=over 4

=item C<my $members = members( $plugin, $tag, [ $cb ] )>

Will ask the specified plugin to resolve the tag. 

If called without a callback, returns an array ref of members on success,
and undef on error.

If called with a callback, it will return immediately and call the callback
later with an array ref containing results:

    sub callback {
        my( $c, $members ) = @_;
          # ...
    }

=back

Plugins need to implement the C<members()> method, taking a tag and an
optional callback. See C<Pogo::Scheduler::Config::TagExternal::Plugin::Example>
for sample code.

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

