###########################################
package Pogo::Util::SSH::Agent;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Object::Event;
use AnyEvent;
use AnyEvent::Util qw( run_cmd );
use File::Temp qw( tempfile );
use POSIX qw( mkfifo O_NONBLOCK O_RDONLY O_WRONLY );

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        fifo_path       => "/tmp/fifo",
        fifo_perms      => 0600,
        ssh_agent       => "ssh-agent",
        ssh_add         => "ssh-add",
        tempdir         => undef,
        ssh_add_timeout => 10,
        %options,
    };

    bless $self, $class;
}

###########################################
sub start {
###########################################
    my( $self, $cb ) = @_;

    my @dir = ();
    @dir = ( DIR => $self->{ tempdir } ) if defined $self->{ tempdir };

    my ($fh, $filename) = tempfile( @dir );
    unlink $filename or LOGDIE "$!";
    $self->{ socket } = $filename;

    DEBUG "Starting $self->{ ssh_agent }";

    # $ ssh-agent -d
    # SSH_AUTH_SOCK=/tmp/ssh-pFEHe26945/agent.26945; export SSH_AUTH_SOCK;
    # echo Agent pid 26945;

    my $cmd = run_cmd [ $self->{ ssh_agent }, "-d", "-a", $filename ],
        "<",  "/dev/null",
        ">",  "/dev/null",
        "2>", "/dev/null",
        '$$', \$self->{ pid },
        ;

    $cmd->cb( sub {
        my( $c ) = @_;

        $c->recv() and 
            LOGDIE "$self->{ ssh_agent } failed ($!)";
    } );

        # Wait and poll until socket exists
    my $cv = AnyEvent->condvar();
    my $ssh_add_starttime = time();

    my $timer; $timer = AnyEvent->timer( 
        after    => 0, 
        interval => 1,
        cb       => sub {
            if( -e $filename ) {
                $cv->send( 1 );
            }
            if( time() - $ssh_add_starttime >
                $self->{ ssh_add_timeout } ) {
                DEBUG "Tired of waiting for ssh-add";
                $cv->send( 0 );
                undef $timer;
            }
        } 
    );

    if( $cv->recv() ) {
        DEBUG "Socket $filename exists";
        $cb->( $filename, $self->{ pid } );
    }
}

###########################################
sub key_add {
###########################################
    my( $self, $key ) = @_;

    DEBUG "Adding key to fifo";
    $self->fifo_setup( $key );

    $ENV{ SSH_AUTH_SOCK } = $self->{ socket };
    my $cmd = run_cmd [ $self->{ ssh_add }, $self->{ fifo_path } ];
    $cmd->recv();
    DEBUG "Key added to fifo";
}

###########################################
sub socket {
###########################################
    my( $self ) = @_;

    return $self->{ socket };
}

###########################################
sub fifo_setup {
###########################################
    my( $self, $key ) = @_;

    {
      no warnings;
      require "sys/ioctl.ph";
    }

    my @dir = ();
    @dir = ( DIR => $self->{ tempdir } ) if defined $self->{ tempdir };

    my ($fh, $filename) = tempfile( @dir );
    unlink $filename or LOGDIE "$!";

    mkfifo $filename, $self->{ fifo_perms } or 
        die "mkfifo failed: $!";

    $self->{ fifo_path } = $filename;

    DEBUG "Opening pipe for reading";

    sysopen my $fdr, $filename, O_NONBLOCK|O_RDONLY or
        die "Opening pipe $filename for reading failed: $!";

    DEBUG "Opening pipe for writing";

    sysopen my $fdw, $filename, O_NONBLOCK|O_WRONLY or
        die "Opening pipe $filename for writing failed: $!";

    $self->{ fifo_w_fd } = $fdw;
    $self->{ fifo_r_fd } = $fdr;
    $self->{ fifo_path } = $filename;

    syswrite $fdw, $key;

    DEBUG "Bytes left: ", fifo_bytecount( $fdr ), "\n";

    $self->{ fifo_refresher } = AnyEvent->timer(
        after    => 1, 
        interval => 1,
        cb => sub {
            my $bytes_left = fifo_bytecount( $fdr );
            DEBUG "Timer: Bytes left in pipe: $bytes_left";
    
            if( $bytes_left == 0 ) {
                DEBUG "Refilling buffer";
                syswrite $fdw, $key;
                DEBUG "Buffer refilled";
                $bytes_left = fifo_bytecount( $fdr );
                DEBUG "After refill: Bytes left in pipe: $bytes_left";
            }
        }
    );
}

###########################################
sub fifo_cleanup {
###########################################
    my( $self ) = @_;

      # stop refreshing the pipe
    $self->{ fifo_refresher } = undef;

    close $self->{ fifo_w_fh };
    close $self->{ fifo_r_fh };

    unlink $self->{ fifo_path };
}

###########################################
sub fifo_bytecount {
###########################################
    my( $fd ) = @_;

    my $size = pack("L", 0);
    ioctl( $fd, FIONREAD(), $size)
    || die "Couldn't call ioctl: $!";
    $size = unpack("L", $size);
}

###########################################
sub shutdown {
###########################################
    my( $self ) = @_;

    kill 2, $self->{ pid } or 
        die "Can't kill pid $self->{ pid } ($!)";

    if( -e $self->{ socket } ) {
        unlink $self->{ socket } or
            die "Can't unlink $self->{ socket } ($!)";
    }
}

###########################################
sub DESTROY {
###########################################
    my( $self ) = @_;

    $self->shutdown();
}

1;

__END__

=head1 NAME

Pogo::Util::SSH::Agent - Start ssh-agent and add keys to it

=head1 SYNOPSIS

    use Pogo::Util::SSH::Agent;

    my $agent = Pogo::Util::SSH::Agent->new();

    $agent->start( sub {
        my( $auth_sock, $agent_pid ) = @_;

        # ...
    } );

    $agent->key_add( $private_key, sub {
        my( $rc ) = @_;

        # ...
    } );

    $agent->shutdown();

=head1 DESCRIPTION

Pogo::Util::SSH::Agent is an AnyEvent component for starting an ssh-agent
process and feeding private keys to it. It will provide the ssh auth
socket the agent is listening on, which can be used later when invoking
the C<ssh> command, which will look in an environment variable name
C<$SSH_AUTH_SOCK> for the unix socket file path.

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=item C<auth_socket()>

Set/get the auth socket the agent is listening on.

=item C<start()>

Starts the ssh-agent process.

=item C<key_add( $key_string )>

Adds an ssh private key to the agent without writing it to disk.
Employs some crazy fifo logic to accomplish this.

=item C<shutdown()>

Shuts down the ssh-agent process.

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

