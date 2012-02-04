###########################################
package Pogo::Dispatcher;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Dispatcher::WorkerConnection;
use base qw(Pogo::Object::Event);

our $VERSION = "0.01";

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        %options,
    };

    bless $self, $class;

    return $self;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    my $w = Pogo::Dispatcher::WorkerConnection->new();

    $self->event_forward( { forward_from => $w }, qw( 
        dispatcher_wconn_worker_connect 
        dispatcher_wconn_prepare 
        dispatcher_wconn_cmd_recv 
        dispatcher_wconn_worker_reply_recv ) );

    $w->start();

      # Guard it
    $self->{ worker_conn } = $w;

    DEBUG "Dispatcher starting";
}

###########################################
sub to_worker {
###########################################
    my( $self, $data ) = @_;

    $self->{ worker_conn }->event( "dispatcher_wconn_send_cmd", $data );
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

See Pogo::Dispatcher::WorkerConnection for
C<dispatcher_wconn_connect>, C<dispatcher_prepare>,
C<dispatcher_wconn_cmd_recv>, C<dispatcher_wconn_worker_ack_recv>.

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

