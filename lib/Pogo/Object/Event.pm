###########################################
package Pogo::Object::Event;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use base qw( Object::Event );

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = { %options, };

    bless $self, $class;
}

###########################################
sub event_forward {
###########################################
    my ( $self, $opts, @events ) = @_;

    if ( !exists $opts->{ forward_from } ) {
        LOGDIE "Missing mandatory param 'forward_from'";
    }

    for my $event ( @events ) {
        $opts->{ forward_from }->reg_cb(
            $event => sub {
                my ( $c, @args ) = @_;

                DEBUG "Forwarding event $event from ",
                    ref( $opts->{ forward_from } ), " to ", ref( $self );

                my $target_event = $event;

                if ( $opts->{ prefix } ) {
                    $target_event = $opts->{ prefix } . $event;
                }

                $self->event( $target_event, @args );
            }
        );
    }
}

1;

__END__

=head1 NAME

Pogo::Object::Event - Additional Object::Event functions

=head1 SYNOPSIS

    package Pogo::Foo;
    use base qw(Pogo::Object::Event);

    sub foo {
        my( $self ) = @_;

        my $w = Pogo::Foo::Bar->new();
        $self->event_forward( $w, qw( foo_bar_this foo_bar_that ) );
    }

=head1 DESCRIPTION

Pogo::Object::Event is a helper class derived from Object::Event
which offers the following additional methods.

=head1 METHODS

=over 4

=item C<event_forward( $forward_from, $event_name, ... )>

Registers a callback in the specified C<$forward_from> object that captures 
the specified events and re-emits by the current object. 
Used in components that forward events originating in sub components. 
Passes on all arguments reaching the callback.

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

