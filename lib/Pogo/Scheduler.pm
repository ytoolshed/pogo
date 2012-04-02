###########################################
package Pogo::Scheduler;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use base qw( Pogo::Object::Event );

###########################################
sub new {
###########################################
    my( $class, %options ) = @_;

    my $self = {
        %options,
    };

    bless $self, $class;

    $self->reg_cb( "task_finished", sub {
      # just ignore
    } );

    return $self;
}

###########################################
sub task_add {
###########################################
    my( $self, $task ) = @_;

      # trivial scheduler, just run the task
    DEBUG "Running task $task";
    $self->event( "task_run", $task );
}

###########################################
sub run {
###########################################
    my( $self ) = @_;
}

###########################################
sub config_load {
###########################################
    # ignore any configs
}

1;

__END__

=head1 NAME

Pogo::Scheduler - Schedule Pogo Tasks

=head1 SYNOPSIS

    use Pogo::Scheduler;

    my $s = Pogo::Scheduler->new();

      # register for running scheduled tasks
    $s->reg_cb( "task_run", sub {
        my( $c, $task ) = @_;

        print "Running Task $task\n";

          # indicate to the scheduler that the task
          # is done, it might want to adapt the schedule
        $s->event( "task_finished", $task );
    } );

      # add a task
    $s->task_add( "some_task" );

      # run the scheduler
    $s->run();

      # add more tasks
    $s->task_add( "some_other_task" );

=head1 DESCRIPTION

Pogo::Scheduler is a high-level component that accepts task requests, 
dynamically determines their run order and emits events when the
time has come to put them into the run queue.

Subclasses of Pogo::Scheduler define components running more
complex schedulers, dealing with limited resources or prerequisite 
tasks that have to be completed before their dependents
can start.

Tasks can be arbitrary objects. When the scheduler selects a task to run, 
it sends it a "task_run" event, along with the task object. Subscribers
to the schedulers receive these events, initate running the scheduled
tasks, and optionally report back to the scheduler when they're done, so
that the scheduler may update the schedule accordingly.

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=back

=head1 EVENTS

=head2 Incoming

=over 4

=item C<task_add( $task )>

Subscriber requests a task to be added to the schedule.

=item C<task_finished( $task )>

Subscriber reports that task has been run.

=back

=head2 Outgoing

=over 4

=item C<task_run( $task )>

Task has been scheduled, subscriber should run it.

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
