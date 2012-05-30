###########################################
package Pogo::One;
###########################################
use warnings;
use strict;
use Log::Log4perl qw(:easy);
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
);

use Pogo::Dispatcher;
use Pogo::Worker;
use Pogo::API;
use base qw(Pogo::Object::Event);

###########################################
sub new {
###########################################
    my( $class, %opts ) = @_;

    my $self = {
        %opts,
    };

    bless $self, $class;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    $self->{ worker } = Pogo::Worker->new(
        delay_connect  => sub { 0 },
        dispatchers    => [ 
          "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT" ],
    );
    $self->{ worker }->set_exception_cb ( sub { 
            LOGDIE "Worker died.";
    } );

    $self->{ dispatcher } = Pogo::Dispatcher->new( );
    $self->{ dispatcher }->set_exception_cb ( sub { 
            LOGDIE "Dispatcher died.";
    } );

      # wait until dispatcher is up to start the worker
    $self->{ dispatcher }->reg_cb( "dispatcher_wconn_prepare", sub {
            local *__ANON__ = 'AE:cb:dispatcher_wconn_prepare';
            my( $c, @args ) = @_;

              # start worker when dispatcher is ready
            $self->{ worker }->start();
    });

     $self->{ dispatcher }->start();

     # api server
   my $api_server = Pogo::API->new();
   $api_server->reg_cb( api_server_up  => sub {
       my( $c ) = @_;
       DEBUG "api ready";

       $self->event( "pogo_one_ready" );
   });

   $api_server->standalone();
}

###########################################
sub job_submit {
###########################################
    my( $self, $job ) = @_;

    DEBUG "Job submitted";

    DEBUG "Job done";
    $self->event( "job_done", $job );
}

1;

__END__

=head1 NAME

Pogo::One - All-in-one component for running Pogo in a single process

=head1 SYNOPSIS

    use Pogo::One;

    my $pogo = Pogo::One->new();

    my $job = Pogo::Job->new(
        command => "/bin/ls /",
        targets => [ qw(host1 host2) ],
        config  => $config_file,
    );

    my $main = AnyEvent->condvar();

    $pogo->job_submit( 
        job      => $job,
        job_done => sub {
            $main->send();
        }
    );

    $main->recv();

=head1 DESCRIPTION

This component implements a mini version of Pogo, suitable for running
jobs from the command line, without the need for setting up a web server, 
dispatchers, or workers.

Behind simple interface, it starts up in-process instances of a Pogo 
dispatcher, and a Pogo worker, accepts a single job via C<job_submit()>,
executes it according to the specified schedule, and returns to the caller.

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=item C<job_submit( $job )>

Takes a Pogo::Job object and schedules it.

=back

=head2 OUTGOING EVENTS

=over 4

=item C<job_submit [$job]>

Submit Pogo::Job object to be scheduled and executed.

=back

=head2 OUTGOING EVENTS

=over 4

=item C<job_done [$job]>

Job completed.

=back

=head1 PITFALLS

Behind the simple interface, C<Pogo::One> uses the real Pogo dispatcher and 
worker components to schedule and execute jobs. The components communicate 
via the standard Pogo communication sockets/ports, so to run Pogo::One,
the following ports need to be available on your localhost (all defined
in C<Pogo::Defaults>):

    $POGO_DISPATCHER_RPC_PORT
    $POGO_DISPATCHER_WORKERCONN_PORT
    $POGO_DISPATCHER_CONTROLPORT_PORT
    $POGO_API_TEST_PORT

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

=head1 AUTHOR

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

