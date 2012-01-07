###########################################
package Pogo::Worker;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;

our $VERSION = "0.01";

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        %options,
    };

    bless $self, $class;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    DEBUG "Worker: Starting";

      # start event loop
    AnyEvent->condvar->recv();
}

1;

__END__

=head1 NAME

Pogo::Worker - Pogo Worker Daemon

=head1 SYNOPSIS

    use Pogo::Worker;

    my $worker = Pogo::Worker->new(
      dispatchers => [ "localhost:9979" ]
    );

    Pogo::Worker->start();

=head1 DESCRIPTION

Main code for the Pogo worker daemon. The worker executes tasks handed
down from the dispatcher. Tasks typically consist of connecting to a 
target host and running a command there.

=head1 METHODS

=over 4

=item C<new()>

=item C<start()>

Tries to connect to one or more configured dispatchers, and keeps trying
indefinitely until it succeeds. If the connection is lost, it will 
try to reconnect. Never returns unless there's a catastrophic error.

=back

It receives tasks from the dispatcher and acknowledges receiving them.

For every task received, it sends back an ACK to the dispatcher.
It then creates a child process and executes the task command.

If the task command runs longer than the task timeout value, the
worker terminates the child.

Upon completion of the task (or a timeout), the worker sends a
message to the dispatcher, which sends back and ACK.

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

