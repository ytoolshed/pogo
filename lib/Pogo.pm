###########################################
package Pogo;
###########################################

use strict;
use warnings;

use 5.008;
our $VERSION = "5.00";

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = { %options, };

    bless $self, $class;
}

1;

__END__

=head1 NAME

Pogo - Run commands on many hosts in a controlled manner

=head1 DESCRIPTION

Pogo is a highly scalable system for running arbitrary commands on 
many hosts in a controlled manner. 

It is mostly used for quick mass software deployments on server farms while
making sure only an allowed number of nodes are upgraded in parallel to
ensure business continuity.

=head2 Project Setup

Pogo is hosted on Github at 

    https://github.com/ytoolshed/pogo

The latest stable version can be found on the master branch. The project 
is automatically being tested on every commit, using travis-ci's service:

    http://travis-ci.org/#!/ytoolshed/pogo

=head2 Architecture

Pogo consists of several components, which can be all running on the same
system, or, in order to scale it, be replicated and even be installed on 
many distributed hosts. Those components are

=over 4

=item Client

Users submit jobs to pogo using the client, which in turn 
contacts the API.

=item API

Takes requests via HTTP from the client and forwards them to a dispatcher.

=item Dispatcher

Takes job requests from the API, figures out constraints, and determines
single tasks the job consists of. It then assigns tasks to workers, 
watches their individual completion and keeps track of overall job 
completion. Dispatchers can be queried by the API to determine the status 
of a given job.

=item Worker

Takes a task (like "ssh to a host and run this command") from the dispatcher,
executes it and reports back the result. Can handle many tasks concurrently.

=back

=head2 Security

To make sure dispatchers and workers communicate over secure channels,
and enable them to authenticate each other (is a connecting worker really
an authorized worker, or is the dispatcher it's connecting to really an
authorized dispatcher?), Pogo uses SSL server and client certs. 
See L<Pogo::Security> for details.

=other bin/pogo-one

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

