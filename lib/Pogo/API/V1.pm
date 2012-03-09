###########################################
package Pogo::API::V1;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use JSON qw( to_json );
use Pogo::Util qw( http_response_json );
use Pogo::Defaults qw(
  $POGO_DISPATCHER_CONTROLPORT_HOST
  $POGO_DISPATCHER_CONTROLPORT_PORT
);
use AnyEvent::HTTP;
use HTTP::Status qw( :constants );
use Plack::Request;
use Data::Dumper;

###########################################
sub app {
###########################################
    my( $class, $dispatcher ) = @_;

    return sub {
        my( $env ) = @_;

        DEBUG "Got v1 request";

        my $path = $env->{ PATH_INFO };
        ( my $command = $path ) =~ s#^/##;

        my %commands = map { $_ => 1} qw( jobinfo jobsubmit );

        if( exists $commands{ $command } ) {
            no strict 'refs';
            DEBUG "Calling $command";
            return $command->( $env );
        }

        return http_response_json(
            { error => [ "unknown request: '$path'" ] }, 
            HTTP_BAD_REQUEST,
        );
    };
}

###########################################
sub jobinfo {
###########################################
    my( $env ) = @_;

    my $req = Plack::Request->new( $env );

    my $params = $req->parameters();

    if( exists $params->{ jobid } ) {

        return http_response_json(
            { rc      => "ok",
              message => "jobid $params->{ jobid }", 
            }
        );
    }

    return http_response_json(
        { rc      => "error",
          message => "jobid missing", 
        }
    );
}

###########################################
sub jobsubmit {
###########################################
    my( $env ) = @_;

    DEBUG "Handling jobsubmit request";

    my $req = Plack::Request->new( $env );

    my $params = $req->parameters();

    if( exists $params->{ cmd } ) {
        return sub {
            my( $response ) = @_;

                # Tell the dispatcher about it (just testing)
            job_post_to_dispatcher( $params->{ cmd }, $response );
        };
    }

    ERROR "No cmd defined";

    return http_response_json(
        { rc      => "error",
          message => "cmd missing", 
        }
    );
}

###########################################
sub job_post_to_dispatcher {
###########################################
    my( $cmd, $response_cb ) = @_;

    my $cp_base_url = "http://" . $POGO_DISPATCHER_CONTROLPORT_HOST .
      ":$POGO_DISPATCHER_CONTROLPORT_PORT";

    DEBUG "Submitting job to $cp_base_url (cmd=$cmd)";

    http_post "$cp_base_url/v1/jobsubmit", "",
        cmd => $cmd,
        sub {
            my( $data, $hdr ) = @_;

            DEBUG "Received $hdr->{ Status } response from $cp_base_url";

            my $rc;
            my $message;

            eval {
                $data = from_json( $data );
            };

            if( $@ ) {
                $rc       = "fail";
                $message = "invalid json";
            } else {
                $rc = $data->{ rc };
                $message = $data->{ message };
            }

            $response_cb->(
              http_response_json(
                { rc       => $rc,
                  message  => $message,
                  status   => $hdr->{ Status },
                }
              )
            );
        };
}

1;

__END__

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

