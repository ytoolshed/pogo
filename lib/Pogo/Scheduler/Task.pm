###########################################
package Pogo::Scheduler::Task;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use base qw(Pogo::Object::Event);

use Pogo::Util qw( make_accessor id_gen );
__PACKAGE__->make_accessor( $_ ) for qw( id slot thread);

use overload ( 'fallback' => 1, '""' => 'as_string' );

###########################################
sub new {
###########################################
    my( $class, %options ) = @_;

    my $self = {
        thread => "no_thread_defined",
        slot   => "no_slot_defined",
        %options,
    };

    $self->{ id } = id_gen( "task" ) if ! defined $self->{ id };

    bless $self, $class;
}

###########################################
sub as_string {
###########################################
    my( $self ) = @_;

    return "$self->{ id }:$self->{ slot }:$self->{ thread }";
}

1;

__END__

=head1 NAME

Pogo::Scheduler::Task - Pogo Scheduler Task Abstraction

=head1 SYNOPSIS

    use Pogo::Scheduler::Task;

    my $task = Pogo::Scheduler::Task->new();

=head1 DESCRIPTION

Pogo::Scheduler::Task abstraction.

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

