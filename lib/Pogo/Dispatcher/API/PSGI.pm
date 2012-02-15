###########################################
package Pogo::Dispatcher::API::PSGI;
###########################################
use strict;
use warnings;

###########################################
sub app {
###########################################
    my( $class ) = @_;

      # Plack app handler
    return sub {
        my( $env ) = @_;

        return [ 200, [ 'Content-Type' => 'text/plain' ], [ 'Hello there' ] ];
    };
}

1;

__END__

=head1 NAME

Pogo::Dispatcher::API::PSGI - Pogo Dispatcher Internal API PSGI interface

=head1 SYNOPSIS

    use Pogo::Dispatcher::API::PSGI;
    my $app = Pogo::Dispatcher::API::PSGI->app();

=head1 DESCRIPTION

App handler for the Pogo dispatcher's internal API.

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

