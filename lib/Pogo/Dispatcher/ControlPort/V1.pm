###########################################
package Pogo::Dispatcher::ControlPort::V1;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use JSON qw( to_json );
use Pogo::Util qw( http_response_json );
use HTTP::Status qw( :constants );
use Plack::Request;
use Data::Dumper;
use Pogo::Scheduler::Classic;

###########################################
sub app {
###########################################
    my ( $class, $dispatcher ) = @_;

    return sub {
        my ( $env ) = @_;

        DEBUG "Got CP v1 request";

        my $path = $env->{ PATH_INFO };
        ( my $command = $path ) =~ s#^/##;

        my %commands = map { $_ => 1 } qw( jobinfo jobsubmit );

        if ( exists $commands{ $command } ) {
            no strict 'refs';
            return $command->( $env, $dispatcher );
        }

        return http_response_json( { error => [ "unknown request: '$path'" ] },
            HTTP_BAD_REQUEST, );
    };
}

###########################################
sub jobinfo {
###########################################
    my ( $env, $dispatcher ) = @_;

    my $req = Plack::Request->new( $env );

    my $params = $req->parameters();

    if ( exists $params->{ jobid } ) {

        return http_response_json(
            {   rc      => "ok",
                message => "jobid $params->{ jobid }",
            }
        );
    }

    return http_response_json(
        {   rc      => "error",
            message => "jobid missing",
        }
    );
}

###########################################
sub jobsubmit {
###########################################
    my ( $env, $dispatcher ) = @_;

    my $req = Plack::Request->new( $env );
    my $job = Pogo::Job->from_query( $req->content() );

    if ( ! $job->valid() ) {
        return http_response_json(
            {   rc      => "nok",
                message => $job->error(),
            }
        );
    }

    my $scheduler = Pogo::Scheduler::Classic->new();
    $scheduler->config_load( \ $job->config() );

    $scheduler->reg_cb( "task_run", sub {
        my( $c, $scheduler_task ) = @_;

        my $host = $scheduler_task->{ host };

        INFO "Running Task. Target: $host";

        $dispatcher->event( "dispatcher_worker_task_received", 
            $scheduler_task, $job->worker_task_data() , $scheduler );
    } );

    DEBUG "Schedule complete: ", $scheduler->as_ascii();
    DEBUG "Scheduling range ", $job->field_as_string( "range" );

    $scheduler->schedule( $job->range );

    return http_response_json(
        {   rc      => "ok",
            message => "dispatcher CP: job received",
        }
    );
}

1;

__END__

=head1 NAME

Pogo::Dispatcher::ControlPort::V1 - Pogo Dispatcher PSGI ControlPort

=head1 SYNOPSIS

    use Pogo::Dispatcher::ControlPort::V1;

    my $app = Pogo::Dispatcher::ControlPort::V1->app();

=head1 DESCRIPTION

PSGI app for Pogo Dispatcher.

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

