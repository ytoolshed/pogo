###########################################
package Pogo::Dispatcher::WorkerConnection;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
);
use base "Object::Event";

our $VERSION = "0.01";

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        protocol => "2.0",
        host     => $POGO_DISPATCHER_WORKERCONN_HOST,
        port     => $POGO_DISPATCHER_WORKERCONN_PORT,
        channels => {
            1 => "worker_dispatcher",
            2 => "dispatcher_worker",
        },
        %options,
    };

    bless $self, $class;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    DEBUG "Starting RPC server on $self->{ host }:$self->{ port }";

      # Start server taking workers connections
    $self->{worker_server_guard} =
        tcp_server( $self->{ host },
                    $self->{ port }, 
                    $self->_accept_handler(),
                    $self->_prepare_handler(),
        );

    $self->reg_cb( "worker_connect", $self->_hello_handler() );
}

###########################################
sub _prepare_handler {
###########################################
    my( $self ) = @_;

    return sub {
        my( $fh, $host, $port ) = @_;

        DEBUG "Listening to $self->{host}:$self->{port} for workers.";
        $self->event( "server_prepare", $host, $port );
    };
}

###########################################
sub _accept_handler {
###########################################
    my( $self ) = @_;

    return sub {
        my( $sock, $peer_host, $peer_port ) = @_;

        DEBUG "$self->{ host }:$self->{ port } accepting ",
              "connection from $peer_host:$peer_port";

        $self->{ handle } = AnyEvent::Handle->new(
            fh       => $sock,
            on_error => sub {
                ERROR "Worker $peer_host:$peer_port can't connect: $_[2]";
                $_[0]->destroy;
            },
            on_eof   => sub {
                INFO "Worker $peer_host:$peer_port disconnected.";
                $self->{ handle }->destroy;
            }
        );

        $self->event( "worker_connect", $peer_host );
    };
}

###########################################
sub _hello_handler {
###########################################
    my( $self ) = @_;

    return sub {
          # Send greeting
        $self->{ handle }->push_write( 
            json => { protocol => $self->{ protocol } } );

          # Handle communication
        $self->{ handle }->push_read( json => $self->_protocol_handler() );
    };
}

###########################################
sub _protocol_handler {
###########################################
    my( $self ) = @_;

      # (We'll put this into a separate module (per protocol) later)
    return sub {
        my( $hdl, $data ) = @_;

        my $channel = $data->{ channel };

        if( !defined $channel ) {
            $self->{ handle }->push_write( json => {
                ok  => 0,
                msg => "No channel given",
            });
            return;
        }

        if( !exists $self->{ channels }->{ $channel } ) {
            $self->{ handle }->push_write( json => {
                ok  => 0,
                msg => "Unsupported channel",
            });
            return;
        }

        INFO "Switching channel to $channel";
        my $method = "channel_$self->{channels}->{$channel}";

        $self->$method( $data );

          # Handle communication
        $self->{ handle }->push_read( json => $self->_protocol_handler() );
    }
}

###########################################
sub channel_worker_dispatcher {
###########################################
    my( $self, $data ) = @_;

    DEBUG "Got worker command: $data->{cmd}";
}

###########################################
sub channel_dispatcher_worker {
###########################################
    my( $self, $data ) = @_;

    DEBUG "Got worker reply: $data->{ok}";
}

1;

__END__

=head1 NAME

Pogo::Dispatcher::WorkerConnection - Pogo worker connection abstraction

=head1 SYNOPSIS

    use Pogo::Dispatcher::WorkerConnection;

    my $guard = Pogo::Dispatcher::WorkerConnection->new();

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=back

=head1 EVENTS

=over 4

=item C<worker_connect>

Fired if a worker connects. Arguments: C<$worker_host>.

=item C<server_prepare>

Fired when the dispatcher is about to bind the worker socket to listen
to incoming workers. Arguments: C<$host>, $C<$port>.

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

