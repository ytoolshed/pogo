###########################################
package PogoFake;
###########################################
use warnings;
use strict;
use Log::Log4perl qw(:easy);
use Pogo::Defaults qw(
  $POGO_DISPATCHER_WORKERCONN_HOST
  $POGO_DISPATCHER_WORKERCONN_PORT
);

use Pogo::Dispatcher;
use Pogo::Worker;
use base qw(Pogo::Object::Event);

###########################################
sub new {
###########################################
    my( $class, %opts ) = @_;

    my $self = {
        main => AnyEvent->condvar,
        tests_done => {},
        %opts,
    };

    bless $self, $class;

    my @ssl = ();

    if( $self->{ ssl } ) {
        @ssl = map { $_ => $self->{ $_ } }
            qw( worker_key worker_cert 
                dispatcher_key dispatcher_cert
                ca_cert
                ssl );
    }

    $self->{ worker } = Pogo::Worker->new(
        delay_connect  => sub { 0 },
        dispatchers    => [ 
          "$POGO_DISPATCHER_WORKERCONN_HOST:$POGO_DISPATCHER_WORKERCONN_PORT" ],
        auto_reconnect => 0,
        @ssl,
    );
    $self->{ worker }->set_exception_cb ( sub { LOGDIE @_; } );

    $self->{ dispatcher } = Pogo::Dispatcher->new( 
        @ssl 
    );
    $self->{ dispatcher }->set_exception_cb ( sub { LOGDIE @_; } );

    return $self;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    my $worker = $self->{ worker };

    my $dispatcher = $self->{ dispatcher };

    $dispatcher->reg_cb( "dispatcher_wconn_prepare", sub {
            local *__ANON__ = 'AE:cb:dispatcher_wconn_prepare';
            my( $c, @args ) = @_;

              # start worker when dispatcher is ready
            $worker->start();
    });

    $self->event_forward( { forward_from => $dispatcher }, qw(
        dispatcher_wconn_worker_connect 
        dispatcher_wconn_prepare 
        dispatcher_wconn_cmd_recv
        dispatcher_wconn_ack
        dispatcher_controlport_up
        dispatcher_controlport_message_received
        dispatcher_worker_task_received
        dispatcher_task_done
    ) );

    $self->event_forward( { forward_from => $worker }, qw(
        worker_dconn_connected
        worker_dconn_listening
        worker_dconn_ack
        worker_dconn_qp_idle
        worker_dconn_cmd_recv
        worker_task_active
        worker_task_done
     ) );

    $dispatcher->start();

    $self->{ tmr } = AnyEvent->timer(
        after    => 0,
        interval => 1,
        cb       => sub {
            local *__ANON__ = 'AE:cb:timer';
            my $tb = Test::More->builder();

              # This is evil, but there doesn't seem to be a better
              # way to peek under Test::More's hood
            my $cur = $tb->{Curr_Test};
            my $exp = $tb->{Expected_Tests};

            DEBUG "Is it done yet ($cur/$exp)?";
            if( $tb->{Curr_Test} == $tb->{Expected_Tests} ) {
                INFO "It is done!";
                $self->quit();
            } else {
                my $logger = Log::Log4perl->get_logger();
                if( $logger->is_debug() ) {
                    DEBUG "Tests remaining: ", 
                          join('-', $self->tests_remaining() );
                }
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
    DEBUG "Quitting event loop by request";
    $self->{ main }->send();
}

###########################################
sub test_done {
###########################################
    my( $self, $test_name ) = @_;

    $self->{ tests_done }->{ $test_name }++;
}

###########################################
sub tests_remaining {
###########################################
    my( $self ) = @_;

    my $tb = Test::More->builder();
    my %remaining = map { $_ => 1 } ( 1 .. $tb->{Expected_Tests} );

    for my $result ( @{ $tb->{Test_Results} } ) {
        if( $result->{ name } =~ /(\d+)$/ ) {
            delete $remaining{ $1 };
        }
    }

    return keys %remaining;
}

1;

__END__

=head1 NAME

PogoFake - Pogo in a Single Process for Testing

=head1 SYNOPSIS

    use PogoFake;

    my $pogo;

    $pogo = PogoFake->new(
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

=head1 AUTHOR

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

