###########################################
package Pogo::Dispatcher::PonyExpress;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::HTTP;
use AnyEvent::Strict;
use HTTP::Request::Common;
use Pogo::Defaults qw(
    $POGO_DISPATCHER_CONTROLPORT_PORT
);
use base qw(Pogo::Object::Event);

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        retries => 3,
        timeout => 10,
        peers   => [ ],
        port    => $POGO_DISPATCHER_CONTROLPORT_PORT,
        %options,
    };

    for my $peer ( @{ $self->{ peers } } ) {

        my $qp = Pogo::Util::QP->new(
            retries => $self->{ retries },
            timeout => $self->{ timeout },
        );

        $self->{ queues }->{ $peer } = $qp;

        $qp->reg_cb( "next", sub {
            my( $c, $data ) = @_;

            my( $peer, $message ) = @$data;

            $self->send_to_peer( $peer, $message, sub {
                $qp->event( "ack" );
            } );
        });
    }

    bless $self, $class;
}

###########################################
sub send {
###########################################
    my( $self, $message ) = @_;

    for my $peer ( @{ $self->{ peers } } )  {
        $self->{ queues }->{ $peer }->event( "push", [ $peer, $message ] );
    }
}

###########################################
sub send_to_peer {
###########################################
    my ( $self, $peer, $data, $success_cb ) = @_;

    my $host = $peer;
    my $port = $POGO_DISPATCHER_CONTROLPORT_PORT;

    if( $peer =~ /(.*?):(.*)/ ) {
        $host = $1;
        $port = $2;
    }

    my $cp = Pogo::Dispatcher::ControlPort->new(
        host => $peer,
        port => $port,
    );

    my $cp_base_url = $cp->base_url();

    my $http_req = POST "$cp_base_url/message", [ data => $data ];

    DEBUG "Posting message to CP of dispatcher $peer";

    http_post $http_req->url(), $http_req->content(),
        headers => $http_req->headers(),
        sub {
            my ( $data, $hdr ) = @_;

            DEBUG "CP of peer $peer returned $hdr->{ Status } on data";

            if( $hdr->{ Status } eq "200" ) {
                $success_cb->();
            }
        };
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

=item C<new( peers => $peers, retries => $retries, timeout => $timeout )>

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

