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
        connected                 => 0,
        args                      => \@opts,
        settings                  => {},
    };

    bless $self, $class;

    $self->{ qp } = Pogo::Util::QP->new( timeout => 5 );
    $self->{ qp }->reg_cb( "next", $self->connect_handler() );

    $self->reg_cb( "connect", sub {
        DEBUG "Received request to connect to ZK";
        $self->{ connected } = 0;
        $self->{ qp }->push( $self->{ zk_host }, $self->{ zk_port } );
    } );

    return $self;
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
        $self->{ zk } = Net::ZooKeeper->new( "$host:$port" );

        DEBUG "Testing ZK connection";
        my $rc = $self->{ zk }->get( "/" );

        if( defined $rc ) {
            INFO "Connected to ZK on $host:$port";
            $self->{ connected } = 1;
            $self->{ qp }->ack();
        } else {
            ERROR "Cannot connect to ZK on $host:$port (", 
                  $self->{ zk }->get_error(), "). Will retry.";
        }
    };
}

###########################################
sub reconnect {
###########################################
    my( $self ) = @_;

    # According to the Net::ZooKeeper docs: 
    # On occasion the ZooKeeper client code may not be able to quickly
    # reconnect to a live server and the caller may want to destroy
    # the existing Net::ZooKeeper handle object and attempt a
    # fresh connection using the same session ID as before with a
    # new Net::ZooKeeper object.  To do so, save the C<session_id>
    # attribute value before undefining the old handle object
    #     and then pass that binary string as the value of the
    # C<'session_id'> option to the C<new()> method when creating the
    # next handle object.

    INFO "Trying to reconnect with ZooKeeper: @{ $self->{ args } }";

    $self->{ zk } = Net::ZooKeeper->new( @{ $self->{ args } } );
    $self->_settings_apply();
    DEBUG "Got new ZooKeeper handle: ", Dumper( $self->{zk} );

    $self->event( "connected", $self->{zk} );
}

###########################################
sub scalar2str {
###########################################
    if(! defined $_[0]) {
        return '[undef]';
    }
    return $_[0];
}

###########################################
sub array2str {
###########################################
    my @array = @_; # copy to modify it in-place
    join ', ', map { scalar2str $_ } @array;
}

  # This logs the ZK method calls and all the arguments we pass
  # to get a better idea what goes in and out of ZooKeeper
for my $method (qw(
    create set exists get delete get_children
    add_auth get_acl set_acl stat watch
)) {
    no strict 'refs';

    *{"Pogo::AnyEvent::ZooKeeper::$method"} = sub {
        my($self, @args) = @_;

        my $wantarray = wantarray;
        my @rc;

        # We perform exactly one immediate retry if we get a 
        # connection error, after trying to reconnect.
        for(1..2) {
            if( $wantarray ) {
                @rc = $self->{zk}->$method( @args );
            } else {
                $rc[0] = $self->{zk}->$method( @args );
            }

            if ( $self->is_hosed() ) {
                ERROR "ZK connection error: ", $self->{zk}->get_error();

                # [bug 4709031] From: ZooKeeper.pm
                # "If the error code is greater than ZAPIERROR, then a 
                # connection error or server error has occurred and the 
                # client should probably close the connection by undefining 
                # the Net::ZooKeeper handle object and, if necessary, attempt 
                # to create a new connection to the ZooKeeper cluster."

                $self->{old_session_id} = $self->{zk}->{session_id};
                $self->{zk} = undef;
                $self->reconnect();
                next;
            }

            last;
        }

          # we want Log4perl to log the code location where this
          # call came from, not this layer
        local $Log::Log4perl::caller_depth = 
              $Log::Log4perl::caller_depth  + 1;

        my $sub = sub {
            my $last_ret = $self->{zk}->get_error();
            my $session_id = $self->{zk}->{session_id};
           
            if( defined $session_id and length $session_id ) {
                $session_id = sprintf "0x%x", 
                    unpack( "q", $session_id );
            } else {
                $session_id = "[no session]";
            }

            my $info = "ZK $session_id $method(" . array2str( @args ) . ")=>";

            if( $wantarray ) {
                my $result = array2str( @rc );

                $info .= logresult( $method, "@args", $result );

                if( @rc == 0 ){
                    $info .= " (err=" . $self->get_error() . ")";
                } else {
                    $info .= " (OK)";
                }

            } else {
                if( defined $rc[0] ){
                    $info .= "(rc=" . scalar2str( $rc[0] ) . ")";
                } else {
                    $info .= "(err=" . $self->get_error() . ")";
                }
            }

            return $info;
        };

        my $zk_error = $self->{zk}->get_error();
        if( $zk_error and $zk_error > ZAPIERROR) {
            INFO $sub;
        } else {
            DEBUG $sub;
        }

        if( $wantarray ) {
            return @rc;
        }
        return $rc[0];
    };
}

###########################################
sub is_hosed {
###########################################
    my( $self, @args ) = @_;

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

###########################################
sub get_error {
###########################################
    my( $self, @args ) = @_;

    return $self->{zk}->get_error( @args );
}

###########################################
sub data_read_len {
###########################################
    my( $self, $value ) = @_;

    if( defined $value ) {
        $self->{ settings }->{ data_read_len } = $value;
        $self->_settings_apply();
    }

    return $self->{ settings }->{ data_read_len };
}

###########################################
sub _settings_apply {
###########################################
    my( $self ) = @_;

    for my $key ( keys %{ $self->{ settings } } ) {
        $self->{zk}->{ $key } = $self->{ settings }->{ $key };
    }
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
        my( $key, $value ) = @_;

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

