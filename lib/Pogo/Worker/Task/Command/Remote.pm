###########################################
package Pogo::Worker::Task::Command::Remote;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Sysadm::Install qw(:all);
use Pogo::Util qw( make_accessor required_params_check id_gen );
use base qw(Pogo::Worker::Task::Command);

__PACKAGE__->make_accessor( $_ ) for qw( 
id command host
user password privkey
stdout stderr rc
);

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        required_params_check( \%options, [ qw( command host user) ] ),
        %options,
    };

    if( !defined $self->{ ssh } ) {
        $self->{ ssh } = bin_find( "ssh" );
    }

    if( !defined $self->{ id } ) {
        $self->{ id } = id_gen( "generic-task-command" );
    }

    bless $self, $class;

    $self->remote_command_fixup();

    return $self;
}

###########################################
sub remote_command_fixup {
###########################################
    my( $self ) = @_;

    my $cmd = "$self->{ ssh } $self->{ host } " . 
              qquote( $self->{ command } );
    
    $self->{ command } = $cmd;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    return $self->SUPER::start( $self->command() );
}

1;

__END__

=head1 NAME

Pogo::Worker::Task::Command::Remote - Pogo Remote Command Executor

=head1 SYNOPSIS

    use Pogo::Worker::Task::Command::Remote;

    my $task = Pogo::Worker::Task::Command::Remote->new(
      host     => "localhost",
      user     => "someuser",
      password => "topsecret",
      command  => "ls -l",
    };

    $task->start();

=head1 DESCRIPTION

Pogo::Worker::Task::Command::Remote is an AnyEvent component for 
running commands on remote hosts via ssh.

It extends C<Pogo::Worker::Task::Command> and takes an extra argument
C<host> to run the given command on the target host.

See the base class C<Pogo::Worker::Task::Command> documentation for how to 
register callbacks.

To authenticate the user on the target system, either a password or a
private key can be provided.

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

