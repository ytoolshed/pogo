###########################################
package Pogo::Dispatcher;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Dispatcher;
use Pogo::Dispatcher::ControlPort;
use Pogo::Dispatcher::Wconn::Pool;
use base qw(Pogo::Object::Event);
use Pogo::Defaults qw(
    $POGO_DISPATCHER_WORKERCONN_HOST
    $POGO_DISPATCHER_WORKERCONN_PORT
);

our $VERSION = "0.01";

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        next_task_id => 1,
        %options,
    };

    bless $self, $class;

    return $self;
}

###########################################
sub start {
###########################################
    my ( $self ) = @_;

    # Handle a pool of workers, as they connect
    my $w = Pogo::Dispatcher::Wconn::Pool->new( %$self );

    $self->event_forward(
        { forward_from => $w }, qw(
            dispatcher_wconn_worker_connect
            dispatcher_wconn_prepare
            dispatcher_wconn_cmd_recv
            dispatcher_wconn_ack )
    );
    $w->start();
    $self->{ wconn_pool } = $w;    # guard it or it'll vanish

    # Listen to requests from the ControlPort
    my $cp = Pogo::Dispatcher::ControlPort->new( dispatcher => $self );
    $self->event_forward(
        { forward_from => $cp }, qw(
            dispatcher_controlport_up )
    );
    $cp->start();
    $self->{ cp } = $cp;           # guard it or it'll vanish

    # if a job comes in ...
    $self->reg_cb(
        "dispatcher_job_received",
        sub {
            my ( $c, $cmd ) = @_;

            # Assign it a dispatcher task ID
            my $id = $self->next_task_id();

            my $task = {
                cmd     => $cmd,
                task_id => $id,
            };

            $self->{ tasks_in_progress }->{ $id } = $task;

            # ... send it to a worker
            DEBUG "Sending cmd $cmd to a worker";
            $self->to_worker( $task );
        }
    );

    # if a completed task report comes back from a worker
    $self->reg_cb(
        "dispatcher_wconn_cmd_recv",
        sub {
            my ( $c, $data ) = @_;
            DEBUG "Dispatcher received worker command: ",
                  "$data->{ cmd } task=$data->{ task_id }";
        }
    );

    DEBUG "Dispatcher started";
}

###########################################
sub next_task_id_base {
###########################################
    my ( $self ) = @_;

    return "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT";
}

###########################################
sub next_task_id {
###########################################
    my ( $self ) = @_;

    my $id = $self->{ next_task_id }++;

    return $self->next_task_id_base() . "-$id";
}

###########################################
sub to_worker {
###########################################
    my ( $self, $data ) = @_;

    $self->{ wconn_pool }->event( "dispatcher_wconn_send_cmd", $data );
}

1;

__END__

=head1 NAME

Pogo::Dispatcher - Pogo Dispatcher Daemon

=head1 SYNOPSIS

    use Pogo::Dispatcher;

    my $worker = Pogo::Dispatcher->new(
      worker_connect  => sub {
          print "Worker $_[0] connected\n";
      },
    );

    Pogo::Dispatcher->start();

=head1 DESCRIPTION

Main code for the Pogo dispatcher daemon. 

Waits for workers to connect.

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=item C<start()>

Starts up the daemon.

=back

=head1 EVENTS

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

