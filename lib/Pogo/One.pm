###########################################
package Pogo::One;
###########################################
use warnings;
use strict;
use JSON qw( from_json );
use Log::Log4perl qw(:easy);
use HTTP::Request::Common;
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
);

use Pogo::Dispatcher;
use Pogo::Worker;
use Pogo::API;
use AnyEvent::HTTP;
use Data::Dumper;
use Pogo::Util qw( make_accessor required_params_check );
use URI;
use base qw(Pogo::Object::Event);

__PACKAGE__->make_accessor( $_ ) for qw( 
api_server
);

###########################################
sub new {
###########################################
    my( $class, %opts ) = @_;

    my $self = {
        %opts,
    };

    $self->{ api_server } = Pogo::API->new();

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

    $self->event_forward(
            { forward_from => $self->{ worker } }, qw(
                worker_task_done
                worker_task_active )
    );

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

    $self->{ dispatcher }->reg_cb( dispatcher_task_done  => sub {
        my( $c, $task_id ) = @_;

        DEBUG "dispatcher_task_done: $task_id";
    });

    $self->{ dispatcher }->start();

      # api server
    $self->{ api_server }->reg_cb( api_server_up  => sub {
       my( $c ) = @_;
       DEBUG "api ready";

       $self->event( "pogo_one_ready" );
    });

    $self->{ api_server }->standalone();
}

###########################################
sub job_submit {
###########################################
    my( $self, $job ) = @_;

    my $base_url = $self->{ api_server }->base_url();

    my $uri = URI->new( "$base_url/jobs" );

    my $request = POST $uri, [ %{ $job->as_hash() } ];
    my $content = $request->content();
    my @headers = ( "headers" => $request->headers() );

    DEBUG "Posting job submit request to uri=$uri";

    http_post $uri, $content, @headers, sub {
        my( $body, $hdr ) = @_;
        my $data = from_json( $body );

        if( !exists $data->{ meta }->{ rc } ) {
            ERROR "Invalid json: from $uri: [$body]";
            return;
        }

        if( $data->{ meta }->{ rc } eq "ok" ) {
            DEBUG "Submitted $job->{ task_name } for hosts ",
                $job->field_as_string( "range" ), " submitted to Web API";
            DEBUG "Response: $data->{ response }->{ message }";
        } else {
            ERROR "rc=$data->{ meta }->{ rc }: $data->{ meta }->{ status }";
        }
    };

    DEBUG "Job done";
    $self->event( "pogo_one_job_submitted", $job );
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

    $pogo->job_submit( 
        job => $job,
    );

    my $main = AnyEvent->condvar();
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

=head2 INCOMING EVENTS

=over 4

=item C<job_submit [$job]>

Submit Pogo::Job object to be scheduled and executed.

=back

=head2 OUTGOING EVENTS

=over 4

=item C<pogo_one_job_submitted [$job]>

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

