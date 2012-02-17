###########################################
package Pogo::Util;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use JSON qw( to_json );

require Exporter;
our @EXPORT_OK = qw( http_response_json );
our @ISA = qw( Exporter );

###########################################
sub http_response_json {
###########################################
    my( $data, $code ) = @_;

    $code = 200 if !defined $code;

    return [ $code, [ 'Content-Type' => 'application/json' ], 
             [ to_json( $data ) ],
           ];
}

1;

__END__

=head1 NAME

Pogo::Util - Pogo Utilities

=head1 SYNOPSIS

    use Pogo::Util qw( http_response_json );

    sub {
       # ... 
       return http_response_json( { message => "yay!" } );
    }

=head1 DESCRIPTION

Some useful utilities.

=head1 FUNCTIONS

=over 4

=item C<http_response_json( $data, [$code] )> 

Take a data structure and turn it into JSON, take an optional HTTP response 
code (defaults to OK 200) and return a PSGI-compatible structure for apps.

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

