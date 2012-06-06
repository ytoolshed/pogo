###########################################
package Pogo::Worker::Task;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Util qw( make_accessor required_params_check id_gen );
use base 'Object::Event';

__PACKAGE__->make_accessor( $_ ) for qw( id rc message );

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        required_params_check( \%options, [ qw( rc message ) ] ),
        %options,
    };

    if( !defined $self->{ id } ) {
        $self->{ id } = id_gen( "generic-task" );
    }

    bless $self, $class;

    return $self;
}

###########################################
sub ran_ok {
###########################################
    my( $self ) = @_;

    if( $self->{ rc } == 0 ) {
        return 1;
    }

    return 0;
}

1;

__END__

=head1 NAME

Pogo::Worker::Task - Pogo Worker Task

=head1 SYNOPSIS

    use Pogo::Worker::Task;

    my $task = Pogo::Worker::Task->new();

=head1 DESCRIPTION

Pogo::Worker::Task does this and that.

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

