###########################################
package Pogo::Worker;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Worker::Connection;
use Pogo::Worker::Task::Command;
use Pogo::Defaults qw(
    $POGO_DISPATCHER_WORKERCONN_HOST
    $POGO_DISPATCHER_WORKERCONN_PORT
    $POGO_WORKER_DELAY_CONNECT
    $POGO_WORKER_DELAY_RECONNECT
);
use Sys::Hostname;
use base qw(Pogo::Object::Event);

our $VERSION = "0.01";

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        delay_connect => $POGO_WORKER_DELAY_CONNECT,
        dispatchers   => [
            "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT"
        ],
        auto_reconnect => 1,
        tasks          => {},
        %options,
    };

    for my $dispatcher ( @{ $self->{ dispatchers } } ) {

        # create a connection object for every dispatcher
        $self->{ conns }->{ $dispatcher } =
            Pogo::Worker::Connection->new( %$self, worker => $self );
    }

    bless $self, $class;
}

###########################################
sub random_dispatcher {
###########################################
    my ( $self ) = @_;

    # pick a random dispatcher
    my $nof_dispatchers = scalar @{ $self->{ dispatchers } };
    return $self->{ dispatchers }->[ rand $nof_dispatchers ];
}

###########################################
sub start {
###########################################
    my ( $self ) = @_;

    DEBUG "Worker: Starting";

    # we re-emit events we get from any of the dispatcher
    # connections, so consumers don't know/care which
    # dispatcher they came from
    for my $dispatcher ( @{ $self->{ dispatchers } } ) {
        $self->event_forward(
            { forward_from => $self->{ conns }->{ $dispatcher } },
            qw(
                worker_dconn_connected
                worker_dconn_listening
                worker_dconn_ack
                worker_dconn_qp_idle
                worker_dconn_cmd_recv
                )
        );
    }

    # launch connector components for all defined dispatchers
    for my $dispatcher ( @{ $self->{ dispatchers } } ) {
        $self->{ conns }->{ $dispatcher }->start();
    }

    $self->reg_cb(
        "worker_task_request",
        sub {
            my ( $c, $task_id, $cmd, $host ) = @_;

            my $task = $self->task_start( $task_id, $cmd, $host );
            $self->event( "worker_task_active", $task );
        }
    );

      # if we receive a command over the wire, forward it to
      # the command handler
    $self->reg_cb(
        "worker_dconn_cmd_recv",
        sub {
            my ( $c, $task_id, $cmd, $host ) = @_;

            $self->cmd_handler( $task_id, $cmd, $host );
        }
    );

    $self->reg_cb(
        "worker_task_done",
        sub {
            my ( $c, $task ) = @_;

            $self->to_dispatcher(
                {   command => "task_done",
                    task_id => $task->id(),
                    rc      => $task->rc(),
                }
            );
        }
    );
}

###########################################
sub cmd_handler {
###########################################
    my ( $self, $task_id, $cmd, $host ) = @_;

    my %commands = map { $_ => 1 } qw( test );

    if ( exists $commands{ $cmd } ) {
        my $method = $cmd . "_cmd";
        no strict 'refs';
        $self->$method( $task_id, $host );
        return;
    }

    ERROR "Invalid command: $cmd";

    my $task = Pogo::Worker::Task->new(
        rc      => -1,
        message => "Invalid command $cmd",
    );

    $self->event( "worker_task_done", $task );
}

###########################################
sub test_cmd {
###########################################
    my ( $self, $task_id, $host ) = @_;

    $self->event( "worker_task_request", $task_id, "sleep 1", $host );
}

###########################################
sub to_dispatcher {
###########################################
    my ( $self, $data ) = @_;

    # send a command to a random dispatcher
    $self->{ conns }->{ $self->random_dispatcher() }
        ->event( "worker_send_cmd", $data );
}

###########################################
sub task_start {
###########################################
    my ( $self, $task_id, $cmd, $host ) = @_;

    # TODO: start task timeout timer

    my $task = Pogo::Worker::Task::Command->new( 
        command => $cmd, host => $host );
    $task->id( $task_id );

    $task->reg_cb(
        on_finish => sub {
            my ( $c, $rc ) = @_;

            DEBUG "Task ", $task->id(), " ended (rc=$rc)";

            $self->event( "worker_task_done", $task );

            # remove task from tracker hash
            delete $self->{ tasks }->{ $task->id() };
        },
    );

    DEBUG "Worker starting task ", $task->id(), " (cmd=$cmd host=$host)";
    $task->start();

    # save it in the task tracker by its unique id to keep it running
    $self->{ tasks }->{ $task->id() } = $task;

    return $task;
}

1;

__END__

=head1 NAME

Pogo::Worker - Pogo Worker Daemon

=head1 SYNOPSIS

    use Pogo::Worker;

    my $worker = Pogo::Worker->new(
      dispatchers => [ "localhost:9979" ]
      on_connect  => sub {
          print "Connected to dispatcher $_[0]\n";
      },
    );

    Pogo::Worker->start();

=head1 DESCRIPTION

Main code for the Pogo worker daemon. The worker executes tasks handed
down from the dispatcher. Tasks typically consist of connecting to a 
target host and running a command there.

=head1 METHODS

=over 4

=item C<new()>

=item C<start()>

Tries to connect to one or more configured dispatchers, and keeps trying
indefinitely until it succeeds. If the connection is lost, it will 
try to reconnect. Never returns unless there's a catastrophic error.

=back

It receives tasks from the dispatcher and acknowledges receiving them.

For every task received, it sends back an ACK to the dispatcher.
It then creates a child process and executes the task command.

If the task command runs longer than the task timeout value, the
worker terminates the child.

Upon completion of the task (or a timeout), the worker sends a
message to the dispatcher, which sends back and ACK.

=head1 EVENTS

=head2 Emitted

=over 4

=item C<worker_task_active $task >

A task has started.

=item C<worker_task_done $task >

A task is complete.

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

