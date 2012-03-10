###########################################
package Pogo::Dispatcher::Wconn::Connection;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Pogo::Util::QP;
use JSON qw(from_json to_json);
use Data::Dumper;
use base qw(Pogo::Object::Event);

our $VERSION = "0.01";

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        protocol => "2.0",
        channels => {
            0 => "control",
            1 => "worker_to_dispatcher",
            2 => "dispatcher_to_worker",
        },
        qp_retries           => 3,
        qp_timeout           => 5,
        worker_handle => undef,
        %options,
    };

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

    DEBUG "Dispatcher starting wconn connection";

    $self->_hello_handler();

    $self->reg_cb( "dispatcher_wconn_send_cmd", $self->_send_cmd_handler() );

    $self->{ qp }->reg_cb( "next", sub {
        my( $c, $data ) = @_;

        my $json = to_json( $data );

        DEBUG "Dispatcher wconn sending $json";

        $self->{ worker_handle }->push_write( $json . "\n" );
    } );

    $self->event_forward( { forward_from => $self->{ qp }, 
                            prefix       => "dispatcher_wconn_qp_",
                          },
                          qw(idle) );
}

###########################################
sub _hello_handler {
###########################################
    my( $self ) = @_;

    DEBUG "Sending greeting";

    my $data = { msg => "Hello, worker.",
        protocol => $self->{ protocol } };

    # Send greeting
    $self->{ worker_handle }->push_write( 
        to_json( $data ) . "\n" );

    # Handle communication
    $self->{ worker_handle }->push_read( 
        line => $self->_protocol_handler() );
}

###########################################
sub _protocol_handler {
###########################################
    my( $self ) = @_;

    DEBUG "Dispatcher protocol handler";

    # Figure out which channel the message came in on and call the
    # appropriate handler.
    return sub {
        my( $hdl, $data ) = @_;

        DEBUG "Dispatcher received: $data";

        eval { $data = from_json( $data ); };

        if( $@ ) {
            ERROR "Got non-json ($@)";
        } else {
            my $channel = $data->{ channel };

            if( !defined $channel ) {
                $channel = 0; # control channel
            }

            DEBUG "Received message on channel $channel";

            if( !exists $self->{ channels }->{ $channel } ) {
                  # ignore traffic on unsupported channels
                return;
            }
    
            INFO "Switching channel to $channel";
            my $method = "channel_$self->{channels}->{$channel}";
    
              # Call the channel-specific handler
            $self->$method( $data );
        }
    
          # Keep the ball rolling
        $self->{ worker_handle }->push_read( 
            line => $self->_protocol_handler() );
    }
}

###########################################
sub channel_control {
###########################################
    my( $self, $data ) = @_;

    DEBUG "Received control message: ", Dumper( $data );
}

###########################################
sub channel_worker_to_dispatcher {
###########################################
    my( $self, $data ) = @_;

    DEBUG "Received worker command: $data->{cmd}";

    $self->event( "dispatcher_wconn_cmd_recv", $data );

    DEBUG "Sending ack to worker";

    my $out_data = {
        channel => 1,
        type    => "reply",
        ok      => 0,
        msg     => "OK",
    };

      # ACK the command
    $self->{ worker_handle }->push_write( to_json( $out_data ) . "\n" );
}

###########################################
sub channel_dispatcher_to_worker {
###########################################
    my( $self, $data ) = @_;

    DEBUG "Received worker ACK";

    #      'msg' => 'OK',
    #      'ok' => 0,
    #      'type' => 'reply',
    #      'channel' => 2,
    #      'task_id' => 1

    $self->event( "dispatcher_wconn_ack", $data );

    $self->{ qp }->event( "ack" );
}

###########################################
sub _send_cmd_handler {
###########################################
    my( $self ) = @_;

    return sub {
        my( $c, $data ) = @_;

        DEBUG "Dispatcher sending worker command: ", Dumper( $data );

        $self->{ qp }->event( "push", { channel => 2, %$data } );
    };
}

1;

__END__

=head1 NAME

Pogo::Dispatcher::Wconn::Connection - Pogo worker connection abstraction

=head1 SYNOPSIS

    use Pogo::Dispatcher::Wconn::Connection;

    my $guard = Pogo::Dispatcher::Wconn::Connection->new();

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=back

=head1 EVENTS

=over 4

=item C<dispatcher_wconn_cmd_recv>

Fired if the dispatcher receives a command by the worker.

=item C<dispatcher_wconn_worker_reply_recv>

Fired if the dispatcher receives a reply to a command sent to the worker
earlier.

=item C<dispatcher_wconn_ack>

Dispatcher received a worker's ACK on a command sent to it earlier.

=item C<dispatcher_wconn_qp_idle>

The queue processor has accomplished all pending requests.

=back

The communication between dispatcher and worker happens on two 
channels on the same connection. Read the worker's documentation for details.

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

