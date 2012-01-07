###########################################
package Pogo::Worker::Task::Command::Remote;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use base qw(Pogo::Worker::Task::Command);

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        %options,
    };

    bless $self, $class;
}

1;

__END__

=head1 NAME

Pogo::Worker::Task::Command::Remote - Pogo Remote Command Executor

=head1 SYNOPSIS

    use Pogo::Worker::Task::Command::Remote;

    my $cmd = Pogo::Worker::Task::Command::Remote->new(
      host => "localhost",
      cmd  => [ 'ls', '-l' ],
    };

    $cmd->reg_cb(
      on_stdout => sub {
        my($c, $stdout) = @_;
      },
      on_stderr => sub {
        my($c, $stderr) = @_;
      }
      on_eof => sub {
        my($c) = @_;
      }
    );
          
    $cmd->run();

      # Send data to the process's STDIN
    $cmd->stdin($data);

=head1 DESCRIPTION

Pogo::Worker::Task::Command::Remote is an AnyEvent component for 
running commands on remote hosts.

It extends C<Pogo::Worker::Task::Command> and takes an extra argument
C<host> to run the given command on the target host.

See the base class C<Pogo::Worker::Task::Command> documentation for how to 
register callbacks.

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

