###########################################
package Pogo::Dispatcher::PonyExpress;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Defaults qw(
    $POGO_DISPATCHER_CONTROLPORT_HOST
    $POGO_DISPATCHER_CONTROLPORT_PORT
);
use base qw(Pogo::Object::Event);

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        peers => [ ],
        port  => $POGO_DISPATCHER_CONTROLPORT_PORT,
        %options,
    };

    bless $self, $class;
}

###########################################
sub start {
###########################################
    my ( $self ) = @_;

    DEBUG "Starting pony express for ", scalar @{ $self->{ peers } },
        " peer dispatchers.";

    $self->reg_cb(
        "dispatcher_pony_express_send",
        sub {
            my( $c, $message ) = @_;

            $self->send( $message );
        }
    );
}

###########################################
sub send {
###########################################
    my( $self, $message ) = @_;

    $self->event( "dispatcher_pony_express_send", $message );
}

1;

__END__

=head1 NAME

Pogo::Dispatcher::PonyExpress - Distribute messages across all dispatchers

=head1 SYNOPSIS

    use Pogo::Dispatcher::PonyExpress;

    my $pe = Pogo::Dispatcher::PonyExpress->new(
        peers => [ $ip1, $ip2, $ip3 ],
    );

    $pe->send( "message to all dispatchers" );

=head1 DESCRIPTION

This component lets Pogo's dispatchers distribute messages to each other.
It is used for the distributed password store.

Every dispatcher is running an instance of C<Pogo::Dispatcher::PonyExpress>.
It maintains persistent TCP connections to all peer dispatchers (reconnecting
if necessary).

The C<send()> method takes a message, and delivers it to the control
ports of all peer dispatchers, retrying if necessary.

=head1 METHODS

=over 4

=item C<new( peers => $peers )>

Constructor. The C<peers> parameter holds a reference to an array with
the IP addresses of all peer dispatchers.

=item C<start()>

Starts the connector.

=item C<send( $message )>

Sends the message to the CPs of all connected dispatchers.

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

