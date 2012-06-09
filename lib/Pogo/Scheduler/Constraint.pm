###########################################
package Pogo::Scheduler::Constraint;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use base qw(Pogo::Object::Event);

use Pogo::Util qw( make_accessor id_gen );
__PACKAGE__->make_accessor( $_ ) for qw( id );

use overload ( 'fallback' => 1, '""' => 'as_string' );

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        max_parallel => undef,
        tasks_active => 0,
        %options,
    };

    if ( !defined $self->{ max_parallel } ) {
        LOGDIE "mandatory parameter max_parallel not set";
    }

    bless $self, $class;

    $self->reg_cb(
        "task_mark_done",
        sub {
            $self->task_mark_done();
        }
    );

    $self->{ id } = id_gen( "constraint" ) if !defined $self->{ id };

    return $self;
}

###########################################
sub kick {
###########################################
    my ( $self ) = @_;

    if ( !$self->blocked() ) {
        $self->{ tasks_active }++;
        DEBUG "Emitting task_next";
        $self->event( "task_next" );
        return 1;
    }

    # We're blocked, let consumers know
    $self->event( "waiting" );
    return 0;
}

###########################################
sub task_mark_done {
###########################################
    my ( $self ) = @_;

    $self->{ tasks_active }--;
}

###########################################
sub blocked {
###########################################
    my ( $self ) = @_;

    return $self->{ tasks_active } >= $self->{ max_parallel };
}

###########################################
sub as_string {
###########################################
    my ( $self ) = @_;

    return $self->{ id };
}

1;

__END__

=head1 NAME

Pogo::Scheduler::Constraint - Pogo Scheduler Constraint Handler

=head1 SYNOPSIS

    use Pogo::Scheduler::Constraint;

    my $constraint = Pogo::Scheduler::Constraint->new(
       max_parallel => 3,
    );

    $constraint->reg_cb( "task_next", sub {
           # ... run next task
           # ... when done:
           $constraint->event( "task_mark_done" );
    } );

      # Kick off the first task
    $constraint->kick();

=head1 DESCRIPTION

Pogo::Scheduler::Constraint abstraction. 

=head2 METHODS

=head2 EVENTS

=over 4

=item C<task_next>

Emitted when the next task in a slot can be scheduled.

=item C<task_mark_done>

Consumed. Sent by the component user when the task, previously emitted
by C<task_next> is complete. Refills the constraint slot.

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

