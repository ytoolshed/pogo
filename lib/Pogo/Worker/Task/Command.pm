###########################################
package Pogo::Worker::Task::Command;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use AnyEvent::Util qw( run_cmd );
use base qw(Pogo::Worker::Task);

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        cmd  => undef,
        host => undef,
        %options,
    };

    if ( !defined $self->{ cmd } ) {
        LOGDIE "parameter 'cmd' missing";
    }

    bless $self, $class;
}

###########################################
sub start {
###########################################
    my ( $self ) = @_;

    $DB::single = 1;

    DEBUG "Starting command $self->{ cmd }";

    $self->{ guard } = run_cmd $self->{ cmd },
        "<",  "/dev/null",
        ">",  $self->on_stdout(),
        "2>", $self->on_stderr(),
        ;

    $self->{ guard }->cb(
        sub {
            my $rc = shift->recv;
            $self->event( "on_finish", $rc );
        }
    );
}

###########################################
sub on_stdout {
###########################################
    my ( $self ) = @_;

    return sub {
        my ( $data ) = @_;

        if ( !defined $data ) {
            # DEBUG "Eof event";
            # $self->event( "on_finish" );
            return 1;
        }

        DEBUG "Stdout event: [$data]";
        $self->event( "on_stdout", $data );
    };
}

###########################################
sub on_stderr {
###########################################
    my ( $self ) = @_;

    return sub {
        my ( $data ) = @_;

        if ( !defined $data ) {
            return 1;
        }

        DEBUG "Stderr event: [$data]";
        $self->event( "on_stderr", $data );
    };
}

###########################################
sub as_string {
###########################################
    my ( $self ) = @_;

    return "$self: cmd=$self->{ cmd } host=$self->{ host }";
}

1;

__END__

=head1 NAME

Pogo::Worker::Task::Command - Pogo Command Executor

=head1 SYNOPSIS

    use Pogo::Worker::Task::Command;

    my $cmd = Pogo::Worker::Task::Command->new(
      cmd  => [ 'ls', '-l' ],
    };

    $cmd->reg_cb(
      on_stdout => sub {
        my($c, $stdout) = @_;
      },
      on_stderr => sub {
        my($c, $stderr) = @_;
      }
      on_finish => sub {
        my($c) = @_;
      }
    );
          
    $cmd->start();

=head1 DESCRIPTION

Pogo::Worker::Task::Command is an AnyEvent component for 
running commands.

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

