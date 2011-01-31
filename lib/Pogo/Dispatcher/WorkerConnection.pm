package Pogo::Dispatcher::WorkerConnection;

# Copyright (c) 2010, Yahoo! Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use 5.008;
use common::sense;

use AnyEvent::Handle;
use AnyEvent::TLS;
use Log::Log4perl qw(:easy);

use constant DEFAULT_PORT => 9697;

sub accept
{
  my ( $class, $fh, $host, $port ) = @_;

  my $self = {
    fh   => $fh,
    host => $host,
    port => $port,
  };

  bless( $self, $class );

  $self->{handle} = AnyEvent::Handle->new(
    fh      => $fh,
    tls     => 'accept',
    tls_ctx => {
      key_file  => Pogo::Dispatcher->dispatcher_key,
      cert_file => Pogo::Dispatcher->dispatcher_cert,
      ca_file   => Pogo::Dispatcher->worker_cert,
      verify    => 1,
      verify_cb => sub {
        local *__ANON__ = 'handle:verify';
        my $preverify_ok = $_[4];
        my $cert         = $_[6];
        DEBUG sprintf( "certificate: %s", AnyEvent::TLS::certname($cert) );
        return $preverify_ok;
      },
    },
    keepalive   => 1,
    on_starttls => sub {
      local *__ANON__ = 'handle:starttls';
      my $success = $_[1];
      my $msg     = $_[2];
      INFO sprintf( "Received connection from worker at %s:%d", $host, $port );
      if ($success)
      {
        INFO sprintf( "SSL/TLS handshake completed with worker at %s:%d", $host, $port );
        $self->{active_tasks} = 0;
        Pogo::Dispatcher->enlist_worker($self);
      }
      else
      {
        $self->{handle}->destroy;
        ERROR sprintf( "Failed to complete SSL/TLS handshake with worker at %s:%d: %s",
          $host, $port, $msg );
      }
    },
    on_eof => sub {
      $self->{handle}->destroy;
      ERROR sprintf( "Unexpected EOF received from worker at %s:%d", $host, $port );
      Pogo::Dispatcher->retire_worker($self);
    },
    on_error => sub {
      $self->{handle}->destroy;
      my $msg = $_[2];
      ERROR sprintf( "I/O error occurred while communicating with worker at %s:%d: %s",
        $host, $port, $msg );
      Pogo::Dispatcher->retire_worker($self);
    },
    on_read => sub {
      $self->{handle}->push_read(
        json => sub {
          my ($req) = $_[1];
          my ( $cmd, @args ) = @$req;
          if ( $cmd eq 'idle' )
          {
            $self->{active_tasks}-- if $self->{active_tasks} > 0;
            Pogo::Dispatcher->idle_worker($self);
          }
          elsif ( $cmd eq 'start' )
          {
            my ( $jobid, $host, $outputurl ) = @args;
            my $job = Pogo::Engine->job($jobid);
            LOGDIE "Nonexistent job $jobid sent from worker " . $self->id unless $job;
            $job->start_task( $host, $outputurl );
          }
          elsif ( $cmd eq 'finish' )
          {
            my ( $jobid, $host, $exitcode, $msg ) = @args;
            my $job = Pogo::Engine->job($jobid);
            LOGDIE "Nonexistent job $jobid sent from worker " . $self->id unless $job;
            $self->{active_tasks}-- if $self->{active_tasks} > 0;
            $job->finish_task( $host, $exitcode, $msg );
          }
          elsif ( $cmd eq 'ping' )
          {
            $self->{handle}->push_write( json => ["pong"] );
          }
        }
      );
    },
  );
  return $self;
}

# {{{ queue_task
# sends a task to the worker for execution
sub queue_task
{
  my ( $self, $job, $host ) = @_;

  # Sanity check
  $self->{active_tasks}++;
  Pogo::Dispatcher->busy_worker($self);

  DEBUG sprintf( "%s: %s assigned to worker %s:%d", $job->id, $host, $self->{host}, $self->{port} );

  # Tell worker what to do
  $self->{handle}->push_write(
    json => [
      "execute",
      { job_id   => $job->id,
        command  => $job->worker_command,
        user     => $job->user,
        run_as   => $job->run_as,
        password => $job->password,
        host     => $host,
        timeout  => $job->timeout,
        secrets  => $job->secrets,
      }
    ]
  );
}

# }}}

sub active_tasks
{
  my $self = shift;
  return $self->{active_tasks};
}

sub id
{
  my $self = shift;
  return sprintf '%s:%d', $self->{host}, $self->{port};
}

1;

=pod

=head1 NAME

  CLASSNAME - SHORT DESCRIPTION

=head1 SYNOPSIS

CODE GOES HERE

=head1 DESCRIPTION

LONG_DESCRIPTION

=head1 METHODS

B<methodexample>

=over 2

methoddescription

=back

=head1 SEE ALSO

L<Pogo::Dispatcher>

=head1 COPYRIGHT

Apache 2.0

=head1 AUTHORS

  Andrew Sloane <asloane@yahoo-inc.com>
  Michael Fischer <mfischer@yahoo-inc.com>
  Nicholas Harteau <nrh@yahoo-inc.com>
  Nick Purvis <nep@yahoo-inc.com>
  Robert Phan <rphan@yahoo-inc.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
