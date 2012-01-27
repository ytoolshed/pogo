###########################################
package PogoOne;
###########################################
use warnings;
use strict;
use Log::Log4perl qw(:easy);
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
  $POGO_DISPATCHER_RPC_HOST
  $POGO_DISPATCHER_RPC_PORT
);

use Pogo::Dispatcher;
use Pogo::Worker;
use base qw(Pogo::Object::Event);

###########################################
sub new {
###########################################
    my( $class ) = @_;

    my $self = {
        main => AnyEvent->condvar,
    };

    bless $self, $class;

    return $self;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    my $worker = $self->{ worker } = Pogo::Worker->new(
        delay_connect => 0,
        dispatchers => [ 
          "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT" ]
    );

    my $dispatcher = $self->{ dispatcher } = Pogo::Dispatcher->new();

    $dispatcher->reg_cb( "dispatcher_wconn_prepare", sub {
            my( $c, @args ) = @_;

              # start worker when dispatcher is ready
            $worker->start();
    });

    $self->event_forward( $dispatcher, qw(
        dispatcher_wconn_worker_connect 
        dispatcher_wconn_prepare 
        dispatcher_wconn_worker_cmd_recv 
        dispatcher_wconn_worker_reply_recv ) );

    $self->event_forward( $worker, qw(
        worker_connected ) );

    $dispatcher->start();

    $self->{ tmr } = AnyEvent->timer(
        after    => 0,
        interval => 1,
        cb       => sub {
            my $tb = Test::More->builder();

              # This is evil, but there doesn't seem to be a better
              # way to peek under Test::More's hood
            my $cur = $tb->{Curr_Test};
            my $exp = $tb->{Expected_Tests};

            TRACE "Is it done yet ($cur/$exp)?";
            if( $tb->{Curr_Test} == $tb->{Expected_Tests} ) {
                $self->quit();
            }
        }
    );

      # start event loop
    $self->{ main }->recv();
}

###########################################
sub quit {
###########################################
    my( $self ) = @_;

      # quit event loop
    $self->{ main }->send();
}

1;

__END__

=head1 NAME

PogoOne - Pogo in a Single Process for Testing

=head1 SYNOPSIS

    use PogoOne;

    my $pogo;

    $pogo = PogoOne->new(
      worker_connect  => sub {
          print "Worker $_[0] connected\n";
          $pogo->quit();
      },
    );

    $pogo->start();

=head1 DESCRIPTION

Starts up a Pogo dispatcher and a worker connecting to it. Offers a
variety of events a test suite can register to.

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=item C<loop()>

Enters the main event loop.

=item C<quit()>

Quite the main event loop.

=back

=head1 EVENTS

=over 4

=item C<worker_connect [$host]>

Worker connected to the dispatcher.

=item C<dispatcher_prepare [$host, $port]>

Dispatcher is ready to bind.

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

