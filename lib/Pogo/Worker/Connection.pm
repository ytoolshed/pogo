###########################################
package Pogo::Worker::Connection;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use AnyEvent::Socket;
use Data::Dumper;
use Pogo::Defaults qw(
  $POGO_DISPATCHER_RPC_HOST
  $POGO_DISPATCHER_RPC_PORT
  $POGO_WORKER_DELAY_CONNECT
  $POGO_WORKER_DELAY_RECONNECT
);
use base "Pogo::Object::Event";

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        dispatchers => [],
        delay_connect   => $POGO_WORKER_DELAY_CONNECT->(),
        delay_reconnect => $POGO_WORKER_DELAY_RECONNECT->(),
        channels => {
            0 => "control",
            1 => "worker_to_dispatcher",
            2 => "dispatcher_to_worker",
        },
        %options,
    };

    bless $self, $class;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    my $delay_connect = $self->{ delay_connect };
    $delay_connect = $delay_connect->() if ref $delay_connect eq "CODE";

    DEBUG "Connecting to all dispatchers after ${delay_connect}s delay";

    my $timer;
    $timer = AnyEvent->timer(
        after => $delay_connect,
        cb    => sub {
            undef $timer;
            $self->start_delayed();
        }
    );

    $self->reg_cb( "worker_send_cmd", $self->_send_cmd_handler() );
}

###########################################
sub start_delayed {
###########################################
    my( $self ) = @_;

    DEBUG "Connecting to all dispatchers";

    for my $dispatcher ( @{ $self->{ dispatchers } } ) {

        my( $host, $port ) = split /:/, $dispatcher;

        DEBUG "Connecting to dispatcher $host:$port";

        tcp_connect( $host, $port, 
                     $self->_connect_handler( $host, $port ) );
    }
}

###########################################
sub _connect_handler {
###########################################
    my( $self, $host, $port ) = @_;

    return sub {
        my ( $fh, $_host, $_port, $retry ) = @_;

        if( !defined $fh ) {
            ERROR "Connect to $host:$port failed: $!";
            return;
        }

        $self->{dispatcher_handle} = AnyEvent::Handle->new(
            fh       => $fh,
            no_delay => 1,
            on_error => sub { 
                my ( $hdl, $fatal, $msg ) = @_;

                ERROR "Cannot connect to $host:$port: $msg";
            },
            on_eof   => sub { 
                my ( $hdl ) = @_;

                INFO "Dispatcher hung up.";
            },
        );

        DEBUG "Sending event 'worker_connected'";
        $self->event( "worker_connected" );

        $self->{ dispatcher_handle }->push_read( 
            json => $self->_protocol_handler() );
    };
}

###########################################
sub _send_cmd_handler {
###########################################
    my( $self, $data ) = @_;

    return sub {
        DEBUG "Sending worker command";
        $self->{ dispatcher_handle }->push_write( $data );
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

        my $channel = $data->{ channel };

        if( !defined $channel ) {
            $channel = 0; # control channel
            return;
        }

        DEBUG "*** Received message on channel $channel";

        if( !exists $self->{ channels }->{ $channel } ) {
              # ignore traffic on unsupported channels
            return;
        }

        INFO "Switching channel to $channel";
        my $method = "channel_$self->{channels}->{$channel}";

          # Call the channel-specific handler
        $self->$method( $data );

          # Keep the ball rolling
        $self->{ dispatcher_handle }->push_read( 
            json => $self->_protocol_handler() );
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

    DEBUG "Received dispatcher reply";

    $self->event( "worker_dispatcher_reply_recv", $data );
}

###########################################
sub channel_dispatcher_to_worker {
###########################################
    my( $self, $data ) = @_;

    DEBUG "Received dispatcher command: $data->{cmd}";

    $self->event( "worker_dispatcher_cmd_recv", $data );

    $self->{ dispatcher_handle }->push_write( json => {
            type => "reply",
            ok   => 0,
            msg  => "OK",
    });
}

1;

__END__

=head1 NAME

Pogo::Worker::Connection - Pogo worker connection abstraction

=head1 SYNOPSIS

    use Pogo::Worker::Connection;

    my $con = Pogo::Worker::Connection->new();

    $con->enable_ssl();

    $con->reg_cb(
      on_connect => sub {},
      on_request => sub {},
    );

    $con->connect( "localhost", 9997 );

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item C<new()>

Constructor.

    my $worker = Pogo::Worker::Connection->new();

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

