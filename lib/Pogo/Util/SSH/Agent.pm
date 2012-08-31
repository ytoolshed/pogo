###########################################
package Pogo::Util::SSH::Agent;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use AnyEvent;
use AnyEvent::Util qw( run_cmd );
use File::Temp qw( tempfile );
use POSIX qw( mkfifo O_NONBLOCK O_RDONLY O_WRONLY PIPE_BUF );

use base 'Object::Event';

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        fifo_perms        => 0600,
        tempdir           => undef,
        ssh_agent         => "ssh-agent",
        ssh_add           => "ssh-add",
        ssh_add_timeout   => 60,
        ssh_agent_timeout => 60,
        started           => 0,
        fifo_opened       => 0,
        %options,
    };

    bless $self, $class;

    return $self;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    my @dir = ();
    @dir = ( DIR => $self->{ tempdir } ) if defined $self->{ tempdir };

    my ($fh, $filename) = tempfile( @dir, UNLINK => 1 );
    unlink $filename or LOGDIE "$!";
    $self->{ socket } = $filename;

    DEBUG "Starting $self->{ ssh_agent }";

    # $ ssh-agent -d
    # SSH_AUTH_SOCK=/tmp/ssh-pFEHe26945/agent.26945; export SSH_AUTH_SOCK;
    # echo Agent pid 26945;
    #
    # Problem is that ssh-agent checks if it's running in a terminal and
    # if not, will suppress all output. We can either use a pty and grab
    # its output to find the unix socket the agent is listenting on, or
    # force a pre-determined file. We're doing the latter for now until
    # I've figured out how to convince run_cmd to use a pty conduit like
    # POE::Wheel::Run does.

    my $cmd = run_cmd [ $self->{ ssh_agent }, "-d", "-a", $filename ],
        "<",  "/dev/null",
        ">",  "/dev/null",
        "2>", "/dev/null",
        '$$', \$self->{ pid },
        ;

        # Wait and poll until ssh-agent unix socket exists
    my $cv = AnyEvent->condvar();
    my $ssh_agent_starttime = time();

    my $timer; $timer = AnyEvent->timer( 
        after    => 0, 
        interval => 0.5,
        cb       => sub {

            DEBUG "checking for to-be-created ssh-agent socket $filename";
            if( -e $filename ) {
                undef $timer;
                DEBUG "ssh-agent created unix socket: $filename";
                $self->event( "ssh_agent_ready", $filename, $self->{ pid } );
                $self->{ started } = 1;
            }

            if( time() - $ssh_agent_starttime >
                $self->{ ssh_agent_timeout } ) {
                DEBUG "Tired of waiting for $self->{ ssh_agent }";
                $self->fifo_cleanup();
                undef $timer;
                $self->event( "ssh_agent_error", "timeout" );
            }
        } 
    );
}

###########################################
sub key_add {
###########################################
    my( $self, $key ) = @_;

    my $keylen = length( $key );

    DEBUG "Adding key (len=$keylen) to fifo";

    if( $keylen > PIPE_BUF ) {
        ERROR "Key too long (max is ", PIPE_BUF, ")";
        $self->event( "ssh_key_added_fail" );
    }

    $self->fifo_setup( $key );

    $ENV{ SSH_AUTH_SOCK } = $self->{ socket };
    my $cmd = run_cmd [ $self->{ ssh_add }, $self->{ fifo_path } ],
    "2>" => "/dev/null",
       # useless because ssh-add suppresses messages unless it's 
       # on a tty, but at least suppresses tty output during testing
    ;

    $cmd->cb( sub {
        my $rc = $cmd->recv();

        if( $rc == 0 ) {
            DEBUG "Key added to fifo";
            $self->event( "ssh_key_added_ok" );
        } else {
            ERROR "$self->{ ssh_add } reported error: $!";
            $self->event( "ssh_key_added_fail" );
        }
    } );
}

###########################################
sub socket {
###########################################
    my( $self ) = @_;

    return $self->{ socket };
}

###########################################
sub fifo_path {
###########################################
    my( $self ) = @_;

    return $self->{ fifo_path };
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

    my ($fh, $filename) = tempfile( @dir, UNLINK => 1 );
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

    $self->{ fifo_opened } = 1;

    syswrite $fdw, $key;

    DEBUG "Bytes left: ", fifo_bytecount( $fdr ), "\n";

    $self->{ fifo_refresher } = AnyEvent->timer(
        after    => 1, 
        interval => 1,
        cb => sub {
            my $bytes_left = fifo_bytecount( $fdr );
            # DEBUG "Timer: Bytes left in pipe: $bytes_left";
    
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

    if( ! $self->{ fifo_opened } ) {
        DEBUG "Fifo was never opened";
        return 1;
    }

      # stop refreshing the pipe
    $self->{ fifo_refresher } = undef;

    close $self->{ fifo_w_fd };
    close $self->{ fifo_r_fd };

    unlink $self->{ fifo_path };

    $self->{ fifo_opened } = 0;
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

    if( ! $self->{ started } ) {
        DEBUG "Already shut down";
        return 1;
    }

    DEBUG "Shutting down";

    $self->fifo_cleanup();

    if( kill 0, $self->{ pid } ) {
        DEBUG "$$: $self->{ pid } is running, sending signal";
        if( !kill 2, $self->{ pid } ) {
            ERROR "Can't kill pid $self->{ pid } ($!)";
            return undef;
        }
        INFO "Waiting for $self->{ ssh_agent } (pid $self->{ pid }) to ",
          "terminate ...";
        waitpid( $self->{ pid }, 0 );
        INFO "$self->{ pid } is gone.";
    }

    for my $file ( $self->{ socket }, $self->{ fifo_path } ) {
        next if !defined $file;
        next if !-e $file;

        DEBUG "Removing $file.";
        if( !unlink $file ) {
            ERROR "Can't unlink $file ($!)";
            return undef;
        }
    }

    DEBUG "Shutdown complete.";
    $self->event( "shutdown_complete" );

    $self->{ started } = 0;
    return 1;
}

###########################################
sub test_run {
###########################################
    my( $bin_dir ) = @_;

    require Test::More;
    require Sysadm::Install;

    my $agent = Pogo::Util::SSH::Agent->new();

    my $cv = AnyEvent->condvar();

    my $g1 = $agent->reg_cb( "ssh_key_added_ok", sub {
        my( $message ) = @_;

        Test::More::ok( 1, "key added" );

        DEBUG "*** fifo path is ", $agent->fifo_path();
        DEBUG "*** socket is ", $agent->socket();
        DEBUG "SSH_AUTH_SOCK=", $agent->socket(), " ssh localhost";

        $cv->send();
    } );

    my $g2 = $agent->reg_cb( "ssh_key_add_failed", sub {
            Test::More::ok( 0, "key added" );
    } );

    my $g3 = $agent->reg_cb( "shutdown_complete", sub {
            Test::More::ok( 1, "shutdown_complete" );
    } );

    my $g4 = $agent->reg_cb( "ssh_agent_ready", sub {
        my( $auth_sock, $agent_pid ) = @_;

        Test::More::ok( 1, "auth socket reported" );

        DEBUG "auth_sock is $auth_sock";
        $agent->key_add( test_privkey() );
    } );

    $agent->start();

    $cv->recv();

    $agent->shutdown();
}

###########################################
sub test_privkey {
###########################################
    return <<EOT;
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEA1fbGvcRmGy6oVrtbVqqjMM3LEVgUkzvCZhsLxdj2ptvWex8U
vatlYUqtdlKg03dwf8XBdi4zLOpu6zPEFi8XvaxaBeBz7NxmF9CDIzuWw1NM+mZP
ukGPYyzXWDWfVGLJGFYtqrAYtKoAaO+46EW2V2sfaTWcCjUdvGVl0/7klfiNnR80
iwBbuv0UOCVE4D7Vz3phUHuVGFs/1FLCOyXVZyDrQPHVkW4AT1RjDjMyHm0w/cs1
YI2wKU0kKKFdHmBbQXw2twMWZbCteYUENRASh/BUeNVNDznqlrFSID+38KiMqT/O
u1qImTOehXsOiXlI9i2ZCfCmEmEAYq0LQC838QIBIwKCAQBn7OQwSXNsSdy8aaFk
nAYfBN75y7I44oL+ZOh2CkvqpUrrWD1GLq2Vp+3aYqXjDiCzFujwQlNe9YZU++Lm
NCF5YlecdFWQTcswI3LlOjNI7fIwetZEhj5UvgIyKKx5cc9jl5KGGwSvhcWvT914
Idw5FsYdKKrgYvEvnvbx8NVtaTU+mWxoRe0PYXMsiI3oEvSYl9HLkQUqbhN1Y5T+
Zuoog9i0c+cTfgDFqoCB5JA5rzAB/5o3cwlg9urPMIDbf0tE1hsaFuNwuKR8x7QY
RLW1shULyye9wO6VAxnQwS68mXhjJEVJFCa3himwWf7RRC6zQ5dlf31MJQis8REG
g/vbAoGBAPZiAfRfHS/wbwj0qu1NuAPRlGyMINaK2JdV1GABBkLmDg5wsLrGgK6C
EVuiP2yQ9vPReR5jlkoZ3lC+PH0yJ8hvvQEC0HV+WI++jyMTYvpTptYcEGs/U7Pm
7RGhDCsZiPbmkGFum46b5kQkiDj7HrNENSYHi+CpDTWrdgSMhlYFAoGBAN5Q0lHr
y60jXAAF6Lrw9mHw6Z8wTkqBctrJC7cBLZJLxy23Fj8MNTIYL0okSmBh/n/7B50/
gwd0+f8LHyHsFGFEBmdRTsyk6wdQpgTvtjivJiXbE4/975bIRWWzS3fpayVvCmYu
wqpHOSKqk+cMsBduEvAEQCzbniJEGYlL5HH9AoGAd6vyUh+R1XTIN4zIDNybNQ4G
Q1oBUkNwhAUeAr6rRRCnvd72wR6WRiHrLIIBjIDs+hVJdSkOe8Nr+1UWEOx5uSBU
fNV7McEGcbRUJvrJrMmLjJFJzbELZgJzJdHhVsNCho0+0D0Juku4/IbF0oiZ4gsv
wgOqVy2KEsD+zwJtIncCgYEA1/a9rqqLV7vy+LVIexX2qEkddhGrI841Dwxxx7gA
Yjr8AIX4WoDjN/o8kSqRZPF64rlX2pV3+J2FI6RnYsgTzDNz71ZMjEhvSO9CMK5Z
PmEAfIusmoGm6j7kVCqD05JK0+g1/Nz3nhlNciIMBQUC1O6WDbr8g1kABAejxzPH
+bMCgYEAhtn+/SlcPRSbh90Ghv2ys67ga3cTFj+hXCotVkvfGGu5nA29QXxkka2y
xx//lsBuHAHFq2rcqktz4VERCgg4nT3v33j13vRFEZpkMl33aYXnc1vvIur8NZHE
hNV0NLsHq/b8VjnRzNBWqjKQXeIUurGtt2Bso/xGkYRFEfUim88=
-----END RSA PRIVATE KEY-----
EOT
}

1;

__END__

=head1 NAME

Pogo::Util::SSH::Agent - Start ssh-agent and add keys to it

=head1 SYNOPSIS

    use Pogo::Util::SSH::Agent;

    my $agent = Pogo::Util::SSH::Agent->new();

    my $cv = AnyEvent->condvar();

    $agent->reg_cb( "ssh_agent_ready", sub {
        my( $auth_sock, $agent_pid ) = @_;

        $agent->key_add( $private_key );
        # ...
    } );

    $agent->reg_cb( "ssh_key_added_ok", sub {
        $cv->send();
    };

    $cv->recv();

    $agent->shutdown();

=head1 DESCRIPTION

Pogo::Util::SSH::Agent is an AnyEvent component for starting an ssh-agent
process and feeding private keys to it. It will provide the ssh auth
socket the agent is listening on, which can be used later when invoking
the C<ssh> command, which will look in an environment variable name
C<$SSH_AUTH_SOCK> for the unix socket file path.

=head2 METHODS

=over 4

=item C<new()>

Constructor, uses the following parameters as defaults, override if
you want something else:

        fifo_perms      => 0600,          # permissions settings for fifo
        ssh_agent       => "ssh-agent",   # path to ssh-agent
        ssh_add         => "ssh-add",     # path to ssh-add
        tempdir         => undef,         # fifo dir
        ssh_add_timeout => 10,            # max wait time for ssh-add 

=item C<auth_socket()>

Set/get the auth socket file the agent is listening on.

=item C<start()>

Starts the ssh-agent process.

=item C<key_add( $key_string )>

Adds an ssh private key to the agent without writing it to disk.
Employs some crazy fifo logic to accomplish this.

=item C<shutdown()>

Shuts down the ssh-agent process.

=back

=head2 EVENTS

=over 4

=item C<ssh_agent_ready>

C<ssh-agent> was started and has created the unix socket. Event
carries the ssh-agent's pid as parameter.

=item C<ssh_agent_error>

If the ssh-agent returns an error, this event is emitted with the Unix
error ($!) as an argument.

=item C<ssh_agent_done>

The ssh-agent has been shut down successfully.

=item C<ssh_key_added_ok>

The key has been added to the agent.

=item C<ssh_key_added_fail>

The agent return an error when we tried to add the key.

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

