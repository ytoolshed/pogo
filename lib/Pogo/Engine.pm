###########################################
package Pogo::Engine;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        %options,
    };

    bless $self, $class;
}

1;

__END__

=head1 NAME

Pogo::Engine - Pogo Constraints Processing Engine

=head1 SYNOPSIS

    use Pogo::Engine;

    my $e = Pogo::Engine->new();

=head1 IMPLEMENTATION

    /pogo/
      /targets_ready
        _LOCK
          update-00001  # to update the ready list
        host1
        host2
        ...
      /slots

To take a target from the ready list, the engine tries to delete it. If
it succeeds, it processes the item. If deleting it fails because the host
no longer exists, k

To write out the constraints to a file-system-like hierarchy (e.g.
in ZooKeeper), the engine uses a temporary directory. At the top of the 
hierarchy is an empty "lock" directory. When done, it atomically moves the 
temporary directory into the constraints area of a job. 

To recalculate the ready list of targets, the engine tries to delete
the 'pick-me' token from the constraints area. If it succeeds, it has 
exclusive access to calculate ready targets, based on the constraints
settings.

the ready list. If it fails to delete the token, another engine
is starting the process and our engine needs to stop.

=head1 METHODS

=over 4

=item C<new()>

Constructor.

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

