###########################################
package Pogo::Client::Async;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::HTTP;
use HTTP::Request::Common;
use JSON qw( from_json to_json );
use Pogo::Util qw( make_accessor required_params_check );
use base "Pogo::Object::Event";

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        required_params_check( \%options, [ qw( api_base_url ) ] ),
        %options,
    };

    bless $self, $class;
}

###########################################
sub job_submit {
###########################################
    my ( $self, $params ) = @_;

    required_params_check( $params, 
        [ qw( task_name range config command ) ] );

    use URI;
    my $uri = URI->new( "$self->{ api_base_url }/jobs" );

    my $job = Pogo::Job->new( 
        task_name => $params->{ task_name },
        range     => $params->{ range },
        config    => $params->{ config },
        command   => $params->{ command },
    );

    my $req     = POST $uri, [ %{ $job->as_hash() } ];
    my $content = $req->content();

    http_post $uri, $content, headers => $req->headers(), sub {
        my( $body, $hdr ) = @_;

        if( $hdr->{Status} =~ /^2/ ) {
            my $data = from_json( $body );
            $self->event( "client_job_submit_ok", $data, $job );
            return 1;
        }

        $self->event( "client_job_submit_fail", $hdr, $job );
    };
}

1;

__END__

=head1 NAME

Pogo::Client::Async - Asynchronous Pogo API Client

=head1 SYNOPSIS

    use Pogo::Client::Async;

    my $client = Pogo::Client::Async->new(
        api_base_url => "http://localhost:7657/v1",
    );

    $client->reg_cb( "client_job_submit_ok", sub {
        my( $c, $resp, $job ) = @_;
    } );

    $client->reg_cb( "client_job_submit_fail", sub {
        my( $c, $resp, $job ) = @_;
    } );

    my $config = <<EOT;
tag:
sequence:
    - host3
    - host2
    - host1
EOT

    $client->job_submit( {
        command => "ls -l",
        range   => [ "host1", "host2" ],
        config  => $config,
    } );

=head1 DESCRIPTION

Pogo client component.

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=item C<job_submit( $params )>

The job parameters are defined in C<$params>, a reference to a hash 
with the following entries:

    {  command => "ls -l",
       range   => [ "host1", "host2" ],
       config  => $config,
    }

=back

=head1 OUTGOING EVENTS

=over 4

=item C<client_job_submit_ok [$resp, $job]>

Job submission ok.

=item C<client_job_submit_fail [$resp, $job]>

Job submission failed.

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

