###########################################
package Pogo::AnyEvent::ZooKeeper;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Net::ZooKeeper qw(:errors);
use Data::Dumper;
use Pogo::Util::QP;
use base qw(Pogo::Object::Event);

###########################################
sub new {
###########################################
    my($class, @opts) = @_;

    my $self = {
        zk                        => undef,
        zk_host                   => "localhost",
        zk_port                   => 2181,
        zk_connect_retry_interval => 5,
        zk_method_retries         => 2,
        zk_method_interval        => 10,
        connected                 => 0,
        args                      => \@opts,
        zk_options                => { 
            data_read_len => 1023
        },
    };

    bless $self, $class;

      # connect/reconnect
    $self->{ connector } = Pogo::Util::QP->new( 
        timeout => $self->{ zk_connect_retry_interval } );
    $self->{ connector }->reg_cb( "next", $self->connect_handler() );
    $self->reg_cb( "connect", sub {
        DEBUG "Received request to connect to ZK";
        $self->{ connected } = 0;
        $self->{ connector }->push( $self->{ zk_host }, $self->{ zk_port } );
    } );

      # command queuing
    $self->{ cmd_queue } = Pogo::Util::QP->new(
        timeout => $self->{ zk_method_interval },
        retries => $self->{ zk_method_retries } );
    $self->{ cmd_queue}->reg_cb( "next", $self->cmd_handler() );

    $self->mk_methods();

    return $self;
}

###########################################
sub ping {
###########################################
    my( $self ) = @_;

    DEBUG "Testing ZK connection";

    return 0 if ! defined $self->{ zk };

    my $rc = $self->{ zk }->get( "/" );

    if( defined $rc ) {
        return 1;
    }

    return 0;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

      # Initial connect
    $self->event( "connect" );
}

###########################################
sub connect_handler {
###########################################
    my( $self ) = @_;

    return sub { 
        my( $c ) = @_;

        my $host = $self->{ zk_host };
        my $port = $self->{ zk_port };

        DEBUG "Connecting to ZK on $host:$port";
        $self->{ zk } = Net::ZooKeeper->new( 
            "$host:$port",
            %{ $self->{ zk_options } },
        );

        my $rc = $self->ping();

        if( defined $rc ) {
            INFO "Connected to ZK on $host:$port";
            $self->{ connected } = 1;
            $self->{ connector }->ack();
            $self->event( "zk_connect_ok" );
        } else {
            $self->event( "zk_connect_error", $self->{ zk }->get_error() );
            ERROR "Cannot connect to ZK on $host:$port (", 
                  $self->{ zk }->get_error(), "). Will retry.";
        }
    };
}

###########################################
sub netloc {
###########################################
    my( $self ) = @_;

    return "$self->{ zk_host }:$self->{ zk_port }";
}

###########################################
sub get_error {
###########################################
    my( $self, @args ) = @_;

    if( !defined $self->{zk} ) {
        return "No connected to ZK yet.";
    }

    return $self->{zk}->get_error( @args );
}

###########################################
sub mk_method {
###########################################
    my( $self, $method ) = @_;

    # Make a wrapper of a Net::ZooKeeper function, supporting logging,
    # reconnects, and retries.

    no strict 'refs';


    my $pkg = __PACKAGE__;

    *{"$pkg::$method"} = sub {
        my($self, @args) = @_;

        my $wantarray = wantarray;

          # last arg is callback by convention
        my $callback = pop @args;

        $self->{ cmd_queue }->push(
          { method    => $method,
            callback  => $callback,
            args      => \@args,
            wantarray => $wantarray,
          }
        );
    };
}

###########################################
sub cmd_handler {
###########################################
    my( $self, $data ) = @_;

    my $method    = $data->{ method };
    my $callback  = $data->{ callback };
    my @args      = @{ $data->{ args } };
    my $wantarray = $data->{ wantarray };
    my $logger    = get_logger();

    my @rc;

    no strict 'refs';

    if( $wantarray ) {
        @rc = $self->{zk}->$method( @args );
    } else {
        $rc[0] = $self->{zk}->$method( @args );
    }

    if ( $self->is_hosed() ) {
        ERROR "ZK connection error: ", $self->get_error();

        # ZooKeeper.pm says:
        # "If the error code is greater than ZAPIERROR, then a 
        # connection error or server error has occurred and the 
        # client should probably close the connection by undefining 
        # the Net::ZooKeeper handle object and, if necessary, attempt 
        # to create a new connection to the ZooKeeper cluster."

        # try to re-establish a lost ZK connection
        $self->event( "connect" );

        # Not sending ACK, current operation will be retried
    } else {
        # Success.
        $self->{ cmd_queue }->ack();
        if( $logger->is_debug() ) {
            $self->cmd_log( $method, \@args, \@rc );
        }
        $callback->( $self, @rc );
    }
}

###########################################
sub cmd_log {
###########################################
    my( $self, $method, $args, $rc ) = @_;

    DEBUG "ZK: $method args=", Dumper( $args ), " rc=", Dumper( $rc );
}

###########################################
sub mk_methods {
###########################################
    my( $self ) = @_;

    for my $method (qw(
        create set exists get delete get_children
        add_auth get_acl set_acl stat watch
    )) {
        $self->mk_method( $method );
    }
}

###########################################
sub is_hosed {
###########################################
    my( $self ) = @_;

    my $err =  $self->{zk}->get_error();

    if( $err != ZOK and 
        ( $err eq ZINVALIDSTATE or
          $err eq ZCONNECTIONLOSS
        )
      ) {
          return 1;
      }

      return 0;
}

1;

__END__

=head1 NAME

Pogo::AnyEvent::ZooKeeper - Event-based ZooKeeper Interface

=head1 SYNOPSIS

    use Pogo::AnyEvent::ZooKeeper;

    my $cv = AnyEvent->condvar();

    my $zk = Pogo::AnyEvent::ZooKeeper->new();

    $zk->create( "/some/node", sub {
        my( $rc, $key, $value ) = @_;

        $cv->send();
    });

    # ... other asynchronous stuff happening meanwhile ...

    $cv->recv();

=head1 DESCRIPTION

AnyEvent::ZooKeeper is a asynchronous ZooKeeper client. For now, this
is just a facade around the synchronous Net::ZooKeeper, but soon enough,
the guts will be truly asynchronous, wrapping around the asynchronous
ZooKeeper C API.

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=item C<create( $path, $value )>

Create a new node.

=item C<get( $path )>

Get the value of a node.

=item C<set( $path, $value )>

Set the value of a node.

=item C<delete( $path )>

Delete a node.

=item C<lock( $path )>

Set a lock.

=item C<unlock( $path )>

Release a lock.

=item C< probe() >

Test if we can connect to a ZooKeeper instance.

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

