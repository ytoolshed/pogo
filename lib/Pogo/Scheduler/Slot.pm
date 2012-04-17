###########################################
package Pogo::Scheduler::Slot;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Scheduler::Constraint;
use base qw(Pogo::Object::Event);

use Pogo::Util qw( make_accessor id_gen );
__PACKAGE__->make_accessor( $_ ) for qw( id tasks thread);

use overload ( 'fallback' => 1, '""' => 'as_string' );

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        tasks             => [],
        task_by_id        => {},
        next_task_idx     => 0,
        active_task_by_id => {},
        constraint_cfg    => undef,
        %options,
    };

    $self->{ id } = id_gen( "slot" ) if ! defined $self->{ id };

    bless $self, $class;
}

###########################################
sub task_add {
###########################################
    my( $self, $task ) = @_;

    DEBUG "Adding task $task to slot $self";

    push @{ $self->{ tasks } }, $task;

    $self->{ task_by_id }->{ $task->id() } = $task;

    return 1;
}

###########################################
sub is_constrained {
###########################################
    my( $self ) = @_;

    return defined $self->{ constraint_cfg };
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    DEBUG "Starting slot $self with tasks [",
      join( ", ", @{ $self->{ tasks } } ), "]";

    $self->reg_cb( "task_mark_done", sub {
        my( $c, $task ) = @_;

        $self->task_mark_done( $task );
    });

    if( $self->is_constrained() ) {

        $self->{ constraint } = Pogo::Scheduler::Constraint->new(
            constraint_cfg => $self->{ constraint_cfg },
            task_next      => sub {
                my( $c ) = @_;

                $self->task_next();
            },
        );

    } else {
          # unconstrained, schedule all tasks
        while( my $task = $self->task_next() ) {
            # nothing to do here, task_next does everything
        }
    }
}

###########################################
sub tasks_left {
###########################################
    my( $self ) = @_;

    if( $self->{ next_task_idx } <= $#{ $self->{ tasks } } ) {
        return 1;
    }

    return 0;
}

###########################################
sub task_next {
###########################################
    my( $self ) = @_;

    DEBUG "Slot $self: Determine next task";

    if( ! $self->tasks_left() ) {
        DEBUG "Slot $self: No more tasks";
          # if this slot has no more active tasks (e.g. because
          # it started without tasks in the first place), we're done
        $self->slot_done_notify() if !$self->tasks_active();
        return undef;
    }

    my $task = $self->{ tasks }->[ $self->{ next_task_idx } ];

    $self->{ active_task_by_id }->{ $task->id() } = $task;

    $self->{ next_task_idx }++;

    DEBUG "Slot $self scheduled task $task";
    $self->event( "task_run", $task );

    return $task;
}

###########################################
sub tasks_active {
###########################################
    my( $self ) = @_;

    return scalar keys %{ $self->{ active_task_by_id } };
}

###########################################
sub task_mark_done {
###########################################
    my( $self, $task ) = @_;

    if( exists $self->{ active_task_by_id }->{ $task->id() } ) {
        DEBUG "Marking task ", $task->id(), " done";
        delete $self->{ active_task_by_id }->{ $task->id() };

        if( $self->{ next_task_idx } > $#{ $self->{ tasks } } and
            !$self->tasks_active() ) {
            DEBUG "Slot $self is complete";
            $self->slot_done_notify();
        }

        return 1;
    }

    ERROR "No such active task: ", $task->id();
}

###########################################
sub slot_done_notify {
###########################################
    my( $self ) = @_;

    if( !$self->{ slot_done_notified }++ ) {
        $self->event( "slot_done", $self );
    }
}

###########################################
sub tasks {
###########################################
    my( $self ) = @_;

    return @{ $self->{ tasks } };
}

###########################################
sub as_string {
###########################################
    my( $self ) = @_;

    return "$self->{ id }";
}

1;

__END__

=head1 NAME

Pogo::Scheduler::Slot - Pogo Scheduler Slot Abstraction

=head1 SYNOPSIS

    use Pogo::Scheduler::Slot;

    my $task = Pogo::Scheduler::Slot->new();

=head1 DESCRIPTION

Pogo::Scheduler::Slot abstraction. A slot consists of a queue of
tasks. The queue is processed in sequence, but the slot can process
as many items in parallel as it wishes.

=head2 METHODS

=over 4

=item C<task_next()>

Schedule the next task. Causes a C<task_run> event if there's 
non-scheduled tasks in the queue.

=back

=head2 EVENTS

=over 4

=item C<task_run>

Emitted when a task is scheduled to run.

=item C<slot_done>

Emitted when all tasks in the slot are marked done.

=item C<task_mark_done>

Consumed. Sent by the component user when the task, previously emitted
by C<task_run> is complete. Marks the task as done internally.

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

