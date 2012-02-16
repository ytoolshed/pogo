###########################################
package Pogo::Dispatcher::API::Status;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;

###########################################
sub app {
###########################################
    my( $class, $dispatcher ) = @_;

    return sub {
        my( $env ) = @_;

        DEBUG "Got status request";

        if( $env->{PATH_INFO} eq '/status' ) {
            return [ 200, [ 'Content-Type' => 'application/json' ], 
                          [ to_json( { workers => [
                              $dispatcher->{ wconn_pool }->workers_connected ] 
                            } )
                          ] ];
        } else {
            return [ 200, [ 'Content-Type' => 'text/plain' ], 
                          [ "unknown request: $env->{PATH_INFO}" ] ];
        }
    };
}

1;

__END__

=head1 NAME

Pogo::Dispatcher::API::Status - Pogo Dispatcher PSGI API

=head1 SYNOPSIS

    use Pogo::Dispatcher::API;

    my $app = Pogo::Dispatcher::API->app();

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

