###########################################
package Pogo::API;
###########################################
use strict;
use warnings;
use Plack::App::URLMap;
use Pogo::Plack::Handler::AnyEvent::HTTPD;
use Pogo::Defaults qw(
    $POGO_API_TEST_PORT
    $POGO_API_TEST_HOST
);
use Log::Log4perl qw(:easy);
use Pogo::Util qw( make_accessor );
use base qw(Pogo::Object::Event);

__PACKAGE__->make_accessor( $_ ) for qw( 
host port
);

###########################################
sub new {
###########################################
    my ( $class, $opts ) = @_;

      # host:port to listen on
    my $host = exists $opts->{host} ? $opts->{host} : $POGO_API_TEST_HOST;
    my $port = exists $opts->{port} ? $opts->{port} : $POGO_API_TEST_PORT;

    my $self = {
        host             => $host,
        port             => $port,
        netloc           => undef,
        protocol_version => "v1",
    };

    if( !defined $self->{ netloc } ) {
        $self->{ netloc } = "http://$self->{host}:$self->{port}";
    }

    bless $self, $class;

    return $self;
}

###########################################
sub base_url {
###########################################
    my ( $self ) = @_;

    return "$self->{ netloc }/$self->{ protocol_version }";
}

###########################################
sub standalone {
###########################################
    my ( $self ) = @_;

    DEBUG "Starting standalone API server on ",
        "$self->{host}:$self->{port}";

    $self->{ api_server } = Plack::Handler::AnyEvent::HTTPD->new(
        host => $self->{host},
        port => $self->{port},
    );

    $self->{ api_server }->register_service( Pogo::API->app() );

    DEBUG "Standalone server ready";
    $self->event( "api_server_up", $self->{host}, $self->{port} );
}

###########################################
sub app {
###########################################
    my ( $class ) = @_;

    my $app = Plack::App::URLMap->new();

    # map URLs to modules, like /status => API/Status.pm etc.
    for my $api ( qw( status v1 ) ) {

        my $module = __PACKAGE__;
        $module .= "::" . ucfirst( $api );

        eval "require $module";
        if ( $@ ) {
            die "Failed to load module $module ($@)";
        }

        DEBUG "Mounting /$api to module $module";

        $app->mount( "/$api" => $module->app() );
    }

    return $app;
}

my $app = __PACKAGE__->app();

__END__

=head1 NAME

Pogo::Dispatcher::API - Pogo API PSGI interface

=head1 SYNOPSIS

    use Pogo::API;
    my $app = Pogo::API->app();

=head1 DESCRIPTION

App handler for Pogo's main Web API. Can be used either by a standalone 
server (by calling

    $ plackup lib/Pogo/API.pm

directly or in the test suite) or in apache with C<Plack::Handler::Apache1>.
The apache configuration looks like this:

    <Location />
     SetHandler perl-script
     PerlHandler Plack::Handler::Apache1
     PerlSetVar psgi_app /path/to/app.psgi
    </Location>

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
