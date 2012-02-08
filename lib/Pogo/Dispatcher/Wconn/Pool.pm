###########################################
package Pogo::Dispatcher::Wconn::Pool;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use AnyEvent::Handle;
use AnyEvent::Socket;
use JSON qw(from_json to_json);
use Data::Dumper;
use Pogo::Dispatcher::Wconn::Connection;
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
);
use base qw(Pogo::Object::Event);

our $VERSION = "0.01";

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        host     => $POGO_DISPATCHER_WORKERCONN_HOST,
        port     => $POGO_DISPATCHER_WORKERCONN_PORT,
        %options,
    };

    bless $self, $class;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    DEBUG "Starting worker server on $self->{ host }:$self->{ port }";

      # Start server, accepting workers connections
    $self->{worker_server_guard} =
        tcp_server( $self->{ host },
                    $self->{ port }, 
                    $self->_accept_handler(),
                    $self->_prepare_handler(),
        );

    $self->reg_cb( "dispatcher_wconn_send_cmd", sub {
        my( $cmd, $data ) = @_;
        $self->to_random_worker( $data );
    } );
}

###########################################
sub _prepare_handler {
###########################################
    my( $self ) = @_;

    return sub {
        my( $fh, $host, $port ) = @_;

        DEBUG "Listening to $self->{host}:$self->{port} for workers.";
        $self->event( "dispatcher_wconn_prepare", $host, $port );
    };
}

###########################################
sub _accept_handler {
###########################################
    my( $self ) = @_;

    return sub {
        my( $sock, $peer_host, $peer_port ) = @_;

        DEBUG "$self->{ host }:$self->{ port } accepting ",
              "connection from worker $peer_host:$peer_port";

        my $worker_handle;

        $worker_handle = 
          AnyEvent::Handle->new(
            fh       => $sock,
            no_delay => 1,
            on_error => sub {
                ERROR "Worker $peer_host:$peer_port can't connect: $_[2]";
                $_[0]->destroy();
            },
            on_eof   => sub {
                INFO "Worker $peer_host:$peer_port disconnected.";
                $worker_handle->destroy();
                  # remove dead worker from pool
                delete $self->{ workers }->{ $peer_host };
            }
        );

        my $conn = Pogo::Dispatcher::Wconn::Connection->new(
            worker_handle => $worker_handle
        );

        $self->event_forward( { forward_from => $conn }, qw( 
            dispatcher_wconn_cmd_recv 
            dispatcher_wconn_ack ) );

        $conn->start();
         
          # add worker to the pool
        $self->{ workers }->{ $peer_host } = $conn;

        DEBUG "Firing dispatcher_wconn_worker_connect";
        $self->event( "dispatcher_wconn_worker_connect", $peer_host );
    };
}

###########################################
sub random_worker {
###########################################
    my( $self ) = @_;

      # pick a random worker
    my @workers = keys %{ $self->{ workers } };

    if( !@workers ) {
        return undef;
    }

    my $nof_workers = scalar @workers;
    return $workers[ rand $nof_workers ];
}

###########################################
sub to_random_worker {
###########################################
    my( $self, $data ) = @_;

    my $random_worker = $self->random_worker();

    if( !defined $random_worker ) {
        ERROR "No workers";
        $self->event( "dispatcher_no_workers" );
    }

    DEBUG "Picked random worker $random_worker";

    $self->{ workers }->{ $random_worker }->event(
      "dispatcher_wconn_send_cmd", $data );
}

1;

__END__

=head1 NAME

Pogo::Dispatcher::Wconn::Connection - Pogo worker connection abstraction

=head1 SYNOPSIS

    use Pogo::Dispatcher::Wconn::Pool;

    my $guard = Pogo::Dispatcher::Wconn::Pool->new();

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=back

=head1 EVENTS

=over 4

=item C<dispatcher_wconn_worker_connect>

Fired if a worker connects. Arguments: C<$worker_host>.

=item C<dispatcher_wconn_prepare>

Fired when the dispatcher is about to bind the worker socket to listen
to incoming workers. Arguments: C<$host>, $C<$port>.

=item C<dispatcher_wconn_cmd_recv>

Fired if the dispatcher receives a command by the worker.

=item C<dispatcher_wconn_ack>

Dispatcher received a worker's ACK on a command sent to it earlier.

=item C<dispatcher_no_workers>

Fired if a command has been submitted but there are no workers connected.

=back

The communication between dispatcher and worker happens on two 
channels on the same connection, the following channel numbers map
to different communication directions:

            1 => "worker_to_dispatcher",
            2 => "dispatcher_to_worker",

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

