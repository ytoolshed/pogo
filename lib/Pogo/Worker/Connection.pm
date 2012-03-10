###########################################
package Pogo::Worker::Connection;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Data::Dumper;
use JSON qw(to_json from_json);
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
  $POGO_WORKER_DELAY_CONNECT
);
use Pogo::Util::QP;
use base "Pogo::Object::Event";

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        dispatcher_host => $POGO_DISPATCHER_WORKERCONN_HOST,
        dispatcher_port => $POGO_DISPATCHER_WORKERCONN_PORT,
        delay_connect   => $POGO_WORKER_DELAY_CONNECT,
        channels => {
            0 => "control",
            1 => "worker_to_dispatcher",
            2 => "dispatcher_to_worker",
        },
        qp_retries           => 1,
        qp_timeout           => 10,
        dispatcher_listening => 0,
        auto_reconnect       => 1,

          # reference back to the worker
        worker      => undef,

        ssl         => undef,
        worker_cert => undef,
        worker_key  => undef,
        ca_cert     => undef,
    };

      # actual values overwrite defaults
    for my $key ( keys %$self ) {
        $self->{ $key } = $options{ $key } if exists $options{ $key };
    }

    $self->{ qp } = Pogo::Util::QP->new(
         retries => $self->{ qp_retries },
         timeout => $self->{ qp_timeout },
    );

    bless $self, $class;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

      # we take commands this way, to send them to the dispatcher
    $self->reg_cb( "worker_send_cmd", $self->_send_cmd_handler() );

    $self->reg_cb( "worker_dconn_error", sub {
        my( $c, $msg ) = @_;

        local $Log::Log4perl::caller_depth =
              $Log::Log4perl::caller_depth + 1;

        ERROR "$msg";

        if( $self->{ auto_reconnect } ) {
            $self->event( "start_delayed" );
        }
    } );

      # on receiving this event, (re)start the worker after a delay
    $self->reg_cb( "start_delayed", $self->start_delayed() );
    $self->event( "start_delayed" );

    $self->{ qp }->reg_cb( "next", sub {
        my( $c, $data ) = @_;

        $self->{ dispatcher_handle }->push_write( 
            to_json( $data ) . "\n" );
    } );

    $self->event_forward( { forward_from => $self->{ qp }, 
                            prefix       => "worker_dconn_qp_",
                          },
                          qw(idle) );
}

###########################################
sub start_delayed {
###########################################
    my( $self ) = @_;

    return sub {
        my $delay_connect = $self->{ delay_connect }->();

        DEBUG "Connecting to dispatcher ",
              "$self->{dispatcher_host}:$self->{dispatcher_port} ",
              "after ${delay_connect}s delay";

        my $timer;
        $timer = AnyEvent->timer(
            after => $delay_connect,
            cb    => sub {
                undef $timer;
                $self->start_now();
            }
        );
    };
}

###########################################
sub start_now {
###########################################
    my( $self ) = @_;

    my $host = $self->{ dispatcher_host };
    my $port = $self->{ dispatcher_port };

    DEBUG "Connecting to dispatcher $host:$port";

    tcp_connect( $host, $port,
                 $self->_connect_handler( $host, $port ) );
}

###########################################
sub _connect_handler {
###########################################
    my( $self, $host, $port ) = @_;

    return sub {
        my ( $fh, $_host, $_port, $retry ) = @_;

        if( !defined $fh ) {

            $self->event( "worker_dconn_error",
                "Connect to $host:$port failed: $!" );

            return;
        }

        $self->{dispatcher_handle} = AnyEvent::Handle->new(
            fh       => $fh,
            no_delay => 1,
            on_error => sub { 
                my ( $hdl, $fatal, $msg ) = @_;

                $self->event( "worker_dconn_error", 
                  "Error on connection to $host:$port: $msg" );
            },
            on_eof   => sub { 
                my ( $hdl ) = @_;

                $self->event( "worker_dconn_error", 
                  "Dispatcher hung up" );
            },
            $self->ssl(),
        );

        DEBUG "dispatcher_handle: $self->{dispatcher_handle}";
        DEBUG "Sending event worker_dconn_connected";
        $self->event( "worker_dconn_connected", $host );

        $self->{ dispatcher_handle }->push_read( 
            line => $self->_protocol_handler() );
    };
}

###########################################
sub _send_cmd_handler {
###########################################
    my( $self ) = @_;

    return sub {
        my( $c, $data ) = @_;

        DEBUG "Worker sending command: ", Dumper( $data );

        $self->{ qp }->event( "push", { channel => 1, %$data } );
    };
}

###########################################
sub _protocol_handler {
###########################################
    my( $self ) = @_;

    DEBUG "Worker protocol handler";

      # (We'll put this into a separate module (per protocol) later)
    return sub {
        my( $hdl, $data ) = @_;

        local *__ANON__ = 'AE:cb:_protocol_handler';

        DEBUG "Worker received: $data";

        eval { $data = from_json( $data ); };

        if( $@ ) {
            ERROR "Got non-json ($@)";
        } else {
            my $channel = $data->{ channel };

            if( !defined $channel ) {
                $channel = 0; # control channel
            }

            DEBUG "*** Received message on channel $channel";
    
            if( !exists $self->{ channels }->{ $channel } ) {
                  # ignore traffic on unsupported channels
                return;
            }
    
            my $method = "channel_$self->{channels}->{$channel}";
    
              # Call the channel-specific handler
            $self->$method( $data );
        }

          # Keep the ball rolling
        $self->{ dispatcher_handle }->push_read( 
            line => $self->_protocol_handler() );

        1;
    }
}

###########################################
sub channel_control {
###########################################
    my( $self, $data ) = @_;

    DEBUG "Received control message: ", Dumper( $data );

    if( ! $self->{ dispatcher_listening } ) {
        $self->{ dispatcher_listening } = 1;

        $self->event( "worker_dconn_listening" );
    }

    $self->event( "worker_dconn_control_message", $data );
}

###########################################
sub channel_worker_to_dispatcher {
###########################################
    my( $self, $data ) = @_;

    DEBUG "Received dispatcher reply";

    $self->event( "worker_dconn_ack", $data );
    $self->{ qp }->event( "ack" );
}

###########################################
sub channel_dispatcher_to_worker {
###########################################
    my( $self, $data ) = @_;

    DEBUG "Received dispatcher command: $data->{ cmd }";

    $self->event( "worker_dconn_cmd_recv", 
                  $data->{ task_id }, $data->{ cmd } );

    my $ack = {
        channel => 2,
        type    => "reply",
        ok      => 0,
        task_id => $data->{ task_id },
        msg     => "OK",
    };

    DEBUG "Sending ACK back to handle ", 
          $self->{dispatcher_handle}, ": ", Dumper( $ack );
    $self->{ dispatcher_handle }->push_write( to_json( $ack ) . "\n" );
}

###########################################
sub ssl {
###########################################
    my( $self ) = @_;

    if( ! $self->{ ssl } ) {
        return ();
    }

    return (
       tls => "connect",
       tls_ctx => {
             # worker

             # worker validates server's cert
           verify  => 1,
           ca_file => $self->{ ca_cert },

             # worker provides client cert to server
           cert_file => $self->{ worker_cert },
           key_file  => $self->{ worker_key },
       },
    );
}

1;

__END__

=head1 NAME

Pogo::Worker::Connection - Pogo worker/dispatcher connection abstraction

=head1 SYNOPSIS

    use Pogo::Worker::Connection;

    my $con = Pogo::Worker::Connection->new(
    );

    $con->start();

=head1 DESCRIPTION

Maintains a connection to a single dispatcher. A worker typically maintains
several of these objects.

=head1 METHODS

=over 4

=item C<new()>

Constructor.

    my $worker = Pogo::Worker::Connection->new();

=back

=head1 EVENTS

=over 4

=item C<worker_send_cmd [$data]>

Incoming: Send the given data structure to the dispatcher.

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

