###########################################
package Pogo::API::V1;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use JSON qw( from_json to_json );
use Pogo::Util qw( http_response_json );
use Pogo::Defaults qw(
    $POGO_DISPATCHER_CONTROLPORT_HOST
    $POGO_DISPATCHER_CONTROLPORT_PORT
);
use AnyEvent::HTTP;
use HTTP::Status qw( :constants );
use Plack::Request;
use Data::Dumper;
use HTTP::Request::Common;

=head1 NAME

Pogo::API::V1 - Pogo API Handlers

=head1 SYNOPSIS

=over 4

=item C<GET /v1/jobs?max=10&offset=30>

get 10 jobs, starting at the 31st most recent

=item C<GET /v1/jobs/p0000000012>

get data for job id p0000000012

=item C<POST /v1/jobs>

submit a new job

=item C<PUT /v1/jobs/p0000000007>

alter job id p0000000007

=back

...etc

=head1 DESCRIPTION

Handles URLs like C<GET /v1/jobs/p0000000011>, C<POST /v1/jobs>, etc.

=cut

###########################################
sub app {
###########################################
    my ( $class, $dispatcher ) = @_;

    return sub {
        my ( $env ) = @_;

        my $req = Plack::Request->new( $env );
        my $path   = $req->path;
        my $method = $req->method;

        DEBUG "Got v1 request for $method $path";

        my $jobid_pattern = '[a-z]{1,3}\d{10}';

        # list these in order of precedence
        my @commands = (

            { pattern => qr{^/ping$},
              method  => 'GET',
              handler => \&ping,      },


            # /jobs* handlers

            { pattern => qr{^/jobs$},
              method  => 'GET',
              handler => \&listjobs },

            { pattern => qr{^/jobs/$jobid_pattern$},
              method  => 'GET',
              handler => \&jobinfo },

            { pattern => qr{^/jobs/$jobid_pattern/log$},
              method  => 'GET',
              handler => \&not_implemented },

            { pattern => qr{^/jobs/$jobid_pattern/hosts$},
              method  => 'GET',
              handler => \&not_implemented },

            { pattern => qr{^/jobs/$jobid_pattern/hosts/[^/]+$},
              method  => 'GET',
              handler => \&not_implemented },

            { pattern => qr{^/jobs/last/[^/]+$},
              method  => 'GET',
              handler => \&not_implemented },

            { pattern => qr{^/jobs$},
              method  => 'POST',
              handler => \&jobsubmit },

            # PUT /jobs/[jobid] takes care of:
            # - jobhalt
            # - jobretry
            # - jobresume
            # - jobskip
            # - jobalter
            { pattern => qr{^/jobs/$jobid_pattern$},
              method  => 'PUT',
              handler => \&not_implemented },



            # /namespaces* handlers

            { pattern => qr{^/namespaces$},
              method  => 'GET',
              handler => \&not_implemented },

            { pattern => qr{^/namespaces/[^/]+$},
              method  => 'GET',
              handler => \&not_implemented },

            { pattern => qr{^/namespaces/[^/]+/locks$},
              method  => 'GET',
              handler => \&not_implemented },

            { pattern => qr{^/namespaces/[^/]+/hosts/[^/]+/tags$},
              method  => 'GET',
              handler => \&not_implemented },

            # loads constraints configuration for a namespace
            { pattern => qr{^/namespaces/[^/]+/constraints$},
              method  => 'POST',
              handler => \&not_implemented },



            # /admin* handlers

            { pattern => qr{^/admin/nomas$},
              method  => 'PUT',
              handler => \&not_implemented },

            );

        foreach my $command ( @commands ) {
            if ( $method eq $command->{method}
             and $path   =~ $command->{pattern} ) {
                DEBUG "$path matched pattern $command->{pattern}, dispatching";
                return $command->{handler}->( $req );
            }
        }

        return http_response_json( { error => [ "unknown request: $method '$path'" ] },
            HTTP_BAD_REQUEST, );
    };
}

=pod

=head1 HTTP METHODS

=over 4

=item C<GET /v1/jobs>

List Pogo jobs.


=item C<GET /v1/jobs/:jobid>

Get basic information for a Pogo job.


=item C<GET /v1/jobs/:jobid/log>

Get log for a Pogo job.


=item C<GET /v1/jobs/:jobid/hosts>

Get the target hosts for a Pogo job.


=item C<GET /v1/jobs/:jobid/hosts/:host>

Get the output for a target host in a Pogo job.


=item C<GET /v1/jobs/last/:userid>

Get the last job submitted by a given user.


=item C<POST /v1/jobs>

Submit a new job.


=item C<PUT /v1/jobs/:jobid>

Alter a job. Possible actions are:

=over 4

=item jobhalt

=item jobretry

=item jobresume

=item jobskip

=item jobalter

=back


=item C<GET /v1/namespaces>

List Pogo namespaces.


=item C<GET /v1/namespaces/:namespace>

Get basic information for a namespace.


=item C<GET /v1/namespaces/:namespace/locks>

Get current locks within a namespace.


=item C<GET /v1/namespaces/:namespace/tags>

Get all configured tags for a namespace.


=item C<GET /v1/namespaces/:namespace/constraints>

Get all configured constraints for a namespace.


=item C<POST /v1/namespaces/:namespace/constraints>

Set constraints for a namespace.



=item C<PUT /v1/admin/nomas>

Toggle Pogo API's ability to accept new jobs.

=back

=cut





###########################################
sub ping {
###########################################
    # bare-bones "yes, the API is up" response
    return http_response_json(
        {   rc      => "ok",
            message => 'pong',
        }
    );
}

###########################################
sub listjobs {
###########################################
    my ( $req ) = @_;

    DEBUG "handling listjobs request";

    my $data = from_json( _TEST_DATA() );

    return http_response_json(
        {   rc      => "ok",
            jobs    => $data->{jobs},
        }
    );
}

###########################################
sub jobinfo {
###########################################
    my ( $req ) = @_;

    DEBUG "handling jobinfo request";

    my $jobid;

    unless ( $req->path =~ m{/([^/]+)$}o ) {
        ERROR "Couldn't find job id in path: " . $req->path;
        return http_response_json(
            {   rc      => "error",
                message => "jobid missing from request path " . $req->path,
            }
        );
    }

    $jobid = $1;
    my $job;

    DEBUG "looking up jobinfo for $jobid";

    my $data = from_json( _TEST_DATA() );
    foreach ( @{ $data->{jobs} } ) {
        if ( $jobid eq $_->{jobid} ) {
            $job = $_;
            last;
        }
    }

    unless ( $job ) {
        ERROR "no such job $job";
        return http_response_json(
            {   rc      => "error",
                message => "no such job $jobid",
            }
        );
    }

    return http_response_json(
        {   rc      => "ok",
            job     => $job,
        }
    );
}

###########################################
sub jobsubmit {
###########################################
    my ( $req ) = @_;

    DEBUG "Handling jobsubmit request";

    my $cmd = $req->param( 'cmd' );

    if ( defined $cmd ) {
        DEBUG "cmd is $cmd";
        return sub {
            my ( $response ) = @_;

            # Tell the dispatcher about it (just testing)
            job_post_to_dispatcher( $cmd, $response );
        };
    } else {

        ERROR "No cmd defined";
        return http_response_json(
            {   rc      => "error",
                message => "cmd missing",
            }
        );
    }
}

###########################################
sub job_post_to_dispatcher {
###########################################
    my ( $cmd, $response_cb ) = @_;

    my $cp          = Pogo::Dispatcher::ControlPort->new();
    my $cp_base_url = $cp->base_url();

    DEBUG "Submitting job to $cp_base_url (cmd=$cmd)";

    my $req = POST "$cp_base_url/jobsubmit", [ cmd => $cmd ];

    http_post $req->url(), $req->content(),
        headers => $req->headers(),
        sub {
        my ( $data, $hdr ) = @_;

        DEBUG "Received $hdr->{ Status } response from $cp_base_url: ",
            "[$data]";

        my $rc;
        my $message;

        eval { $data = from_json( $data ); };

        if ( $@ ) {
            $rc      = "fail";
            $message = "invalid json: $@";
        } else {
            $rc      = $data->{ rc };
            $message = $data->{ message };
        }

        $response_cb->(
            http_response_json(
                {   rc      => $rc,
                    message => $message,
                    status  => $hdr->{ Status },
                }
            )
        );
        };
}

###########################################
sub not_implemented {
###########################################
    my ( $req ) = @_;

    my $path   = $req->path;
    my $method = $req->method;

    return http_response_json( { error => [ "not implemented yet: $method '$path'" ] },
                               HTTP_NOT_IMPLEMENTED, );
}



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

=cut

sub _TEST_DATA {

return <<'END_YAML'
{
  "jobs" : [
      {
          "jobid"       : "p0000000008",
          "command"     : "uptime",
          "range"       : "[\"host2.example.com\"]",
          "namespace"   : "example",
          "user"        : "sallyfoo",
          "run_as"      : "sallyfoo",
          "state"       : "finished",
          "concurrent"  : "1",
          "host_count"  : "1",
          "job_timeout" : "15000",
          "timeout"     : "1200",
          "prehook"     : "0",
          "posthook"    : "0",
          "retry"       : "0",
          "requesthost" : "clienthost.example.com",
          "invoked_as"  : "/usr/bin/pogo run -h host2.example.com --concurrent 4 uptime",
          "start_time"  : 1336094397.8485,
          "client"      : "4.0.0"
      },

      {
          "jobid"       : "p0000000007",
          "command"     : "sudo apachectl -k graceful-stop; rpm -iv  SomePkg.3.11.i386.rpm; sudo apachectl -k start; sudo apachectl -k status",
          "range"       : "[\"host1.example.com\"]",
          "namespace"   : "crawler",
          "user"        : "johnqdoe",
          "run_as"      : "johnqdoe",
          "state"       : "finished",
          "concurrent"  : "1",
          "host_count"  : "1",
          "job_timeout" : "15000",
          "timeout"     : "15000",
          "prehook"     : "0",
          "posthook"    : "0",
          "retry"       : "0",
          "requesthost" : "clienthost.example.com",
          "invoked_as"  : "/usr/bin/pogo run -h host2.example.com --concurrent 4 'sudo apachectl -k graceful-stop; rpm -iv  SomePkg.3.11.i386.rpm; sudo apachectl -k start; sudo apachectl -k status'",
          "start_time"  : 1336095397.412,
          "client"      : "4.0.0"
      },

      {
        "jobid"       : "p0000000006",
        "command"     : "sudo apachectl -k restart",
        "range"       : "[\"host2.example.com\"]",
        "namespace"   : "example",
        "user"        : "johnqdoe",
        "run_as"      : "johnqdoe",
        "state"       : "finished",
        "concurrent"  : "1",
        "host_count"  : "1",
        "job_timeout" : "15000",
        "timeout"     : "15000",
        "prehook"     : "0",
        "posthook"    : "0",
        "retry"       : "0",
        "requesthost" : "clienthost.example.com",
        "invoked_as"  : "/usr/bin/pogo run -h host2.example.com --concurrent 4 'sudo apachectl -k restart'",
        "start_time"  : 1336096997.32125,
        "client"      : "4.0.0"
      },

      {
        "jobid"       : "p0000000005",
        "command"     : "whoami; uptime",
        "range"       : "[\"host1.example.com\"]",
        "namespace"   : "crawler",
        "user"        : "sallyfoo",
        "run_as"      : "robotuser",
        "state"       : "finished",
        "concurrent"  : "1",
        "host_count"  : "1",
        "job_timeout" : "15000",
        "timeout"     : "15000",
        "prehook"     : "0",
        "posthook"    : "0",
        "retry"       : "0",
        "requesthost" : "clienthost.example.com",
        "invoked_as"  : "/usr/bin/pogo run -h host2.example.com --concurrent 4 'whoami; uptime'",
        "start_time"  : 1336098399.00825,
        "client"      : "4.0.0"
      },

      {
        "jobid"       : "p0000000004",
        "command"     : "find /some/directory -type f -mmin -20",
        "range"       : "[\"host[1-4].pub.example.com\"]",
        "namespace"   : "publisher",
        "user"        : "sallyfoo",
        "run_as"      : "sallyfoo",
        "state"       : "finished",
        "host_count"  : "1",
        "job_timeout" : "15000",
        "timeout"     : "15000",
        "prehook"     : "0",
        "posthook"    : "0",
        "retry"       : "0",
        "requesthost" : "clienthost.example.com",
        "invoked_as"  : "/usr/bin/pogo run -h host2.example.com --concurrent 4 'find /some/directory -type f -mmin -20'",
        "start_time"  : 1336197397.19378,
        "client"      : "4.0.0"
      }
           ],


  "namespaces" : [
      { "crawler"   : {} },
      { "example"   : {} },
      { "publisher" : {} },
      { "web"       : {} }
                 ]
}

END_YAML
};

1;
