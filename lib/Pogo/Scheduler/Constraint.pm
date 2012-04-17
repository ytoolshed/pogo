###########################################
package Pogo::Scheduler::Constraint;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Scheduler::Constraint;
use base qw(Pogo::Object::Event);

use Pogo::Util qw( make_accessor );
__PACKAGE__->make_accessor( $_ ) for qw( id );

use overload ( 'fallback' => 1, '""' => 'as_string' );

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        constraint_cfg => undef,
        task_next      => undef,
        constraint     => {},
        %options,
    };

    $self->{ id } = id_gen( "constraint" ) if ! defined $self->{ id };

    bless $self, $class;
}

1;

__END__

=head1 NAME

Pogo::Scheduler::Constraint - Pogo Scheduler Constraint Handler

=head1 SYNOPSIS

    use Pogo::Scheduler::Slot;

    my $task = Pogo::Scheduler::Slot->new();

=head1 DESCRIPTION

Pogo::Scheduler::Slot abstraction. A slot consists of a queue of
tasks. The queue is processed in sequence, but the slot can process
as many items in parallel as it wishes.

=head2 METHODS

=head2 EVENTS

=over 4

=item C<task_next>

Emitted when the next task in a slot can be scheduled.

=item C<task_mark_done>

Consumed. Sent by the component user when the task, previously emitted
by C<task_next> is complete. Refills the slot.

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

