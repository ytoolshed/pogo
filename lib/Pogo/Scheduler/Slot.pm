###########################################
package Pogo::Scheduler::Slot;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use base qw(Pogo::Object::Event);

use Pogo::Util qw( make_accessor );
__PACKAGE__->make_accessor( $_ ) for qw( id tasks thread);

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
sub task_add {
###########################################
    my( $self, $task ) = @_;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;
}

###########################################
sub resume {
###########################################
    my( $self ) = @_;
}

###########################################
sub stop {
###########################################
    my( $self ) = @_;
}

1;

__END__

=head1 NAME

Pogo::Scheduler::Slot - Pogo Scheduler Slot Abstraction

=head1 SYNOPSIS

    use Pogo::Scheduler::Slot;

    my $task = Pogo::Scheduler::Slot->new();

=head1 DESCRIPTION

Pogo::Scheduler::Slot abstraction.

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

