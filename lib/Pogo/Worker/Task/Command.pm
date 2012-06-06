###########################################
package Pogo::Worker::Task::Command;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use AnyEvent::Util qw( run_cmd );
use Pogo::Util qw( make_accessor required_params_check id_gen );
use base qw(Pogo::Worker::Task);

__PACKAGE__->make_accessor( $_ ) for qw( 
id command host
stdout stderr rc
);

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        required_params_check( \%options, [ qw( command ) ] ),
        %options,
    };

    if( !defined $self->{ id } ) {
        $self->{ id } = id_gen( "generic-task-command" );
    }

    bless $self, $class;
    return $self;
}

###########################################
sub start {
###########################################
    my ( $self ) = @_;

    DEBUG "Starting command $self->{ command }";

    $self->{ guard } = run_cmd $self->{ command },
        "<",  "/dev/null",
        ">",  $self->on_stdout(),
        "2>", $self->on_stderr(),
        ;

    $self->{ guard }->cb(
        sub {
            my $rc = shift->recv;

            $self->{ rc } = $rc;
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
        $self->{ stdout } .= $data;
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
        $self->{ stderr } .= $data;
        $self->event( "on_stderr", $data );
    };
}

###########################################
sub as_string {
###########################################
    my ( $self ) = @_;

    return "$self: command=$self->{ command }";
}

###########################################
sub DESTROY {
###########################################
    my ( $self ) = @_;

      # help GC by deleting circular ref
    delete $self->{ guard };
}

1;

__END__

=head1 NAME

Pogo::Worker::Task::Command - Pogo Command Executor

=head1 SYNOPSIS

    use Pogo::Worker::Task::Command;

    my $task = Pogo::Worker::Task::Command->new(
      command  => "ls -l",
      id       => "123",
    };

    $task->reg_cb(
      on_stdout => sub {
        my($c, $stdout) = @_;
      },
      on_stderr => sub {
        my($c, $stderr) = @_;
      }
      on_finish => sub {
        my($c) = @_;

        if( $c->rc() ) {
            print "Failure\n";
            return 1;
        }

        print "Task ", $c->id(), " which ran ",
              $c->command(), " finished.\n";
      }
    );
          
    $task->start();

=head1 DESCRIPTION

Pogo::Worker::Task::Command is an AnyEvent component for 
running shell command line commands.

=head1 METHODS

=over 4

=item id()

The task ID.

=item command()

The shell command line to be executed.

=item stdout()

Text that appeared on stdout.

=item stderr()

Text that appeared on stderr.

=item rc()

The return code of the command after completion.

=back

=head1 INCOMING EVENTS

=head1 OUTGOING EVENTS

=over 4

=item C<on_finish $c>

Upon command completion.

=item C<on_stdout $c $lines>

Text appeared on stdout.

=item C<on_stderr $c $lines>

Text appeared on stderr.

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

