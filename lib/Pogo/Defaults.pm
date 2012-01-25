###########################################
package Pogo::Defaults;
###########################################
use strict;
use warnings;
require Exporter;
our @ISA = qw(Exporter);

our @EXPORT_OK = qw(
  $POGO_DISPATCHER_RPC_HOST
  $POGO_DISPATCHER_RPC_PORT
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
);

our $POGO_DISPATCHER_RPC_HOST        = "localhost";
our $POGO_DISPATCHER_RPC_PORT        = 7655;
our $POGO_DISPATCHER_WORKERCONN_HOST = "127.0.0.1";
our $POGO_DISPATCHER_WORKERCONN_PORT = 7654;

1;

__END__

=head1 NAME

Pogo::Defaults - Pogo Variable Defaults

=head1 SYNOPSIS

    package Pogo::SomethingOrAnother;

    use Pogo::Defaults qw(
      $POGO_DISPATCHER_WORKERCONN_HOST
      $POGO_DISPATCHER_WORKERCONN_PORT
    );

    ###########################################
    sub new {
    ###########################################
        my($class, %options) = @_;
    
        my $self = {
            host => $POGO_DISPATCHER_WORKERCONN_HOST,
            port => $POGO_DISPATCHER_WORKERCONN_PORT,
            %options,
        };
    
        bless $self, $class;
    }

=head1 DESCRIPTION

This is the location for all default values.

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

