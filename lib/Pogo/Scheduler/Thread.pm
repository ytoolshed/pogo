###########################################
package Pogo::Scheduler::Thread;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use base qw(Pogo::Object::Event);

use Pogo::Util qw( make_accessor );
__PACKAGE__->make_accessor( $_ ) for qw( id slots );

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        slots => [],
        next_slot_idx => 0,
        active_slot   => undef,
        %options,
    };

    $self->{ id } = id_gen( "thread" ) if ! defined $self->{ id };

    bless $self, $class;
}

###########################################
sub slot_add {
###########################################
    my( $self, $slot ) = @_;

    push @{ $self->{ slots } }, $slot;
}

###########################################
sub slot_next {
###########################################
    my( $self ) = @_;

    if( ! $self->slots_left() ) {
        $self->{ active_slot } = undef;
        $self->event( "thread_done", $self );
        return undef;
    }

    my $slot = $self->{ slots }->{ $self->{ next_slot_idx } };
    $self->{ active_slot } = $slot;

    $self->{ next_slot_idx }++;
    return $slot;
}

###########################################
sub slots_left {
###########################################
    my( $self ) = @_;

    return $self->{ next_slot_idx } <= $#{ $self->{ slots } };
}

###########################################
sub task_mark_done {
###########################################
    my( $self, $task ) = @_;

    if( $self->{ active_slot }->task_mark_done( $task ) ) {
        return 1;
    }
}

1;

__END__

=head1 NAME

Pogo::Scheduler::Thread - Pogo Scheduler Thread Abstraction

=head1 SYNOPSIS

    use Pogo::Scheduler::Thread;

    my $task = Pogo::Scheduler::Thread->new();

=head1 DESCRIPTION

Pogo::Scheduler::Thread abstraction.

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

