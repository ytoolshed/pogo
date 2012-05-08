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

###########################################
sub app {
###########################################
    my ( $class, $dispatcher ) = @_;

    return sub {
        my ( $env ) = @_;

        my $jobid_pattern = '[a-z]{1,3}\d{10}';

        my $path   = $env->{ PATH_INFO };
        my $method = $env->{ REQUEST_METHOD };

        DEBUG "Got v1 request for $method $path";

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
                return $command->{handler}->( $env );
            }
        }

        return http_response_json( { error => [ "unknown request: $method '$path'" ] },
            HTTP_BAD_REQUEST, );
    };
}

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
    my ( $env ) = @_;

    my $req = Plack::Request->new( $env );

    my $params = $req->parameters();

    my $data = from_json( join( '', map { $_ } ( <DATA> ) ) );

    return http_response_json(
        {   rc      => "ok",
            jobs    => $data->{jobs},
        }
    );
}

###########################################
sub jobinfo {
###########################################
    my ( $env ) = @_;

    my $req = Plack::Request->new( $env );

    my $params = $req->parameters();

    if ( exists $params->{ jobid } ) {
        return http_response_json(
            {   rc      => "ok",
                message => "jobid $params->{ jobid }",
            }
        );

    } else {
        return http_response_json(
            {   rc      => "error",
                message => "jobid missing",
            }
        );
    }
}

###########################################
sub jobsubmit {
###########################################
    my ( $env ) = @_;

    DEBUG "Handling jobsubmit request";

    my $req = Plack::Request->new( $env );

    my $params = $req->parameters();

    if ( exists $params->{ cmd } ) {
        DEBUG "cmd is $params->{ cmd }";
        return sub {
            my ( $response ) = @_;

            # Tell the dispatcher about it (just testing)
            job_post_to_dispatcher( $params->{ cmd }, $response );
        };
    }

    ERROR "No cmd defined";

    return http_response_json(
        {   rc      => "error",
            message => "cmd missing",
        }
    );
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
    my ( $env ) = @_;

    my $path   = $env->{ PATH_INFO };
    my $method = $env->{ REQUEST_METHOD };

    return http_response_json( { error => [ "not implemented yet: $method '$path'" ] },
                               HTTP_NOT_IMPLEMENTED, );
}

1;

=head1 NAME

Pogo::API::V1 - Pogo API Handlers

=head1 SYNOPSIS

=head1 DESCRIPTION

Handles URLs like C</v1/jobstatus>, C</v1/jobsubmit>, etc.

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

__DATA__

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

