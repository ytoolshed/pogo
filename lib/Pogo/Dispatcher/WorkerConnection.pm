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
        host => $POGO_DISPATCHER_WORKERCONN_HOST,
        port => $POGO_DISPATCHER_WORKERCONN_PORT,
        %options,
    };

    bless $self, $class;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

      # Start server taking workers connections
    $self->{worker_server} =
        tcp_server( $self->{ host },
                    $self->{ port }, 
                    $self->_accept_handler(),
                    $self->_prepare_handler(),
        );
}

###########################################
sub _prepare_handler {
###########################################
    my( $self ) = @_;

    return sub {
        my( $fh, $host, $port ) = @_;

        $self->event( "server_prepare", $host, $port );
        DEBUG "Listening to $self->{host}:$self->{port} for workers.";
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

        $self->event( "worker_connect", $peer_host );
    };
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

Fired when the server is about to bind a socket. Arguments:
C<$host>, $C<$port>.

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

