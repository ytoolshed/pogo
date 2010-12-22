package Pogo::Worker::Connection;

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

use common::sense;

use AnyEvent;
use AnyEvent::Handle;
use IPC::Open3;
use JSON::XS qw(encode_json);
use Log::Log4perl qw(:easy);
use Pogo::Worker;
use POSIX qw(WEXITSTATUS SIGTERM);
use Time::HiRes qw(time);
use IO::File;
use Scalar::Util qw(refaddr);

sub new    #{{{
{
  my $class = shift;
  my $self  = {@_};

  return bless( $self, $class );
}          #}}}

sub run    #{{{
{
  my $self = shift;

  $self->{dispatcher_handle} = AnyEvent::Handle->new(
    connect => [ $self->{host}, $self->{port} ],
    tls     => 'connect',
    tls_ctx => {
      key_file  => $self->{worker_key},
      cert_file => $self->{worker_cert},
      ca_file   => $self->{dispatcher_cert},
      verify    => 1,
      verify_cb => sub {
        my $preverify_ok = $_[4];
        my $cert         = $_[6];
        DEBUG sprintf( "certificate: %s", AnyEvent::TLS::certname($cert) );
        return $preverify_ok;
      },
    },
    keepalive  => 1,
    on_connect => sub {
      INFO sprintf( "Connected to dispatcher at %s:%d", $self->{host}, $self->{port} );
      Pogo::Worker->add_connection($self);
      while ( my $msg = Pogo::Worker->dequeue_msg )
      {
        DEBUG sprintf( "sending queued response to %s:%d: %s",
          $self->{host}, $self->{port}, encode_json($msg) );
        $self->send_response($msg);
      }
    },
    on_starttls => sub {
      my $success = $_[1];
      my $msg     = $_[2];
      if ($success)
      {
        INFO sprintf( "SSL/TLS handshake completed with dispatcher at %s:%d",
          $self->{host}, $self->{port} );
      }
      else
      {
        $self->{dispatcher_handle}->destroy;
        ERROR sprintf( "Failed to complete SSL/TLS handshake with %s:%d: %s",
          $self->{host}, $self->{port}, $msg );
        $self->reconnect;
      }
    },
    on_connect_error => sub {
      my $msg = $_[1];
      $self->{dispatcher_handle}->destroy;
      ERROR sprintf( "Failed to connect to %s:%d: %s", $self->{host}, $self->{port}, $msg );
      $self->reconnect;
    },
    on_error => sub {
      my $msg = $_[2];
      $self->{dispatcher_handle}->destroy;
      Pogo::Worker->delete_connection($self);
      ERROR sprintf( "I/O error occurred while communicating with %s:%d: %s",
        $self->{host}, $self->{port}, $msg );
      $self->reconnect;
    },
    on_read => sub {
      $self->{dispatcher_handle}->push_read(
        json => sub {
          my $obj = $_[1];
          if ( ref $obj ne 'ARRAY' )
          {
            ERROR sprintf( "Failed to receive a JSON array!  (Got: %s)", encode_json($obj) );
            $self->{dispatcher_handle}->destroy;
            $self->reconnect;
            return;
          }
          my ( $cmd, $args ) = @$obj;
          $self->run_command( $cmd, $args );
        }
      );
    }
  );
}    #}}}

sub host { return shift->{host}; }
sub port { return shift->{port}; }

sub run_command    #{{{
{

  # Currently the only thing that ever comes down this pipe is a request to
  # launch a job.  The dispatcher will send these anytime it receives an EXIT
  # or an IPC idle.  Whenever the code enters here, the worker is always marked
  # busy by the dispatcher.  We can idle ourselves to take more connections.
  my ( $self, $cmd, $args ) = @_;

  my $task_id = join( '/', $args->{job_id}, $args->{host} );
  DEBUG "[$task_id] Received command '$cmd'";
  $self->{tasks}->{$task_id}->{args} = $args;
  DEBUG "Current task count: " . scalar keys %{ $self->{tasks} };
  if ( scalar keys %{ $self->{tasks} } < Pogo::Worker->num_workers )
  {
    $self->send_response( ['idle'] );
  }

  # Any code executed after this point _must_ call $self->reset upon
  # completion or the worker may never receive new job requests.

  my %calls = ( "execute" => \&execute, );

  if ( exists $calls{$cmd} )
  {
    $calls{$cmd}->( $self, $task_id );
  }
  else
  {
    INFO "[$task_id] Received invalid command '$cmd'";
    $self->reset( $task_id, "500", "Invalid command" );
  }
}    #}}}

sub execute    #{{{
{
  my ( $self, $task_id ) = @_;
  my $task = $self->{tasks}->{$task_id};

  for (qw(job_id command user run_as password host timeout))
  {
    return $self->reset( $task_id, "500", "Missing required argument $_" )
      unless defined( $task->{args}->{$_} );
  }
  INFO "[$task_id] Executing job for " . $task->{args}->{user};

  # Disable any existing SIGCHLD handlers that may be interfering
  # with our ability to catch our subprocesses' exit status.
  $SIG{CHLD} = sub { };

  # Launch our helper program
  my ( $writer, $reader ) = ( IO::Handle->new, IO::Handle->new );
  my $pid;
  eval { $pid = open3( $writer, $reader, undef, Pogo::Worker->exec_helper ); };
  if ($@)
  {
    ERROR "[$task_id] Error: $@";
    return $self->reset( $task_id, "500", $@ );
  }

  DEBUG "[$task_id] Launched " . Pogo::Worker->exec_helper . "pid $pid";

  my $job_id    = $task->{args}->{job_id};
  my $host      = $task->{args}->{host};
  my $save_dir  = Pogo::Worker->output_dir . '/' . $job_id;
  my $buf_count = 0;
  my ( $output_filename, $output_url );
  my $n = 0;
  do
  {
    $output_filename = sprintf( "%s/%s/%s.%d.txt", Pogo::Worker->output_dir, $job_id, $host, $n );
    $output_url      = sprintf( "%s/%s/%s.%d.txt", Pogo::Worker->output_uri, $job_id, $host, $n );
    $n++;
  } while ( -f $output_filename );

  mkdir($save_dir) unless ( -d $save_dir );

  # Send args
  $writer->print( encode_json( $task->{args} ) );
  $writer->close;

  Pogo::Worker->send_response( [ 'start', $job_id, $host, $output_url ] );

  my $output_file = IO::File->new( $output_filename, O_WRONLY | O_CREAT | O_APPEND, 0664 )
    or LOGDIE "Couldn't create file '$output_filename': $!";
  $output_file->autoflush(1);
  DEBUG sprintf( "Writing to output file %s", $output_filename );

  # Register callbacks to handle events from spawned process.
  my $write_stdout = sub {
    my $buf = delete $task->{process_handle}->{rbuf};
    $self->write_output_entry( $output_file, { task => $task_id, type => 'STDOUT' }, $buf );
    $buf_count += length($buf);
    if ( Pogo::Worker->max_output && $buf_count >= Pogo::Worker->max_output )
    {
      DEBUG "[$task_id] Max output reached";

      $self->write_output_entry(
        $output_file,
        { task => $task_id, type => 'STDOUT' },
        sprintf( "== Output exceeded maximum length of %d bytes ==\n", Pogo::Worker->max_output )
      );
      kill SIGTERM, $pid;

      # we will be called again during cleanup
      $buf_count = 0;
    }
  };
  my $process_exit = sub {

    # Catch exit code from waitpid
    my $p = waitpid( $pid, 0 );
    my $exit_status = WEXITSTATUS($?);
    DEBUG "[$task_id] Process returned code $exit_status (waitpid returned $p)";

    $write_stdout->();
    $self->write_output_entry( $output_file, { task => $task_id, type => 'EXIT' }, $exit_status );
    $output_file->close;
    undef $output_file;
    delete $task->{process_handle};
    $self->reset( $task_id, $exit_status );
  };
  $task->{process_handle} = AnyEvent::Handle->new(
    fh     => $reader,
    on_eof => sub {
      DEBUG "[$task_id] Received EOF";
      $process_exit->();
    },
    on_error => sub {
      DEBUG "[$task_id] Received error: $!";
      $process_exit->();
    },
    on_read => $write_stdout
  );
}    #}}}

sub send_response    #{{{
{
  my ( $self, $msg ) = @_;
  $self->{dispatcher_handle}->push_write( json => $msg );
}                    #}}}

sub write_output_entry    #{{{
{
  my ( $self, $fh, $args, $data ) = @_;
  $args->{ts} = time();
  $fh->syswrite( encode_json( [ $args, $data ] ) );
  $fh->syswrite("\n");
}                         #}}}

sub reset                 #{{{
{
  my ( $self, $task_id, $code, $msg ) = @_;
  my $task = $self->{tasks}->{$task_id};
  Pogo::Worker->send_response(
    [ 'finish', $task->{args}->{job_id}, $task->{args}->{host}, $code, $msg ] );
  delete $self->{tasks}->{$task_id};
}                         #}}}

sub reconnect             #{{{
{
  my ( $self, $interval ) = @_;
  $interval ||= rand(30);
  INFO sprintf( "Reattempting connection to %s:%d in %.2f seconds.",
    $self->{host}, $self->{port}, $interval );
  my $reconnect_timer;
  $reconnect_timer = AnyEvent->timer(
    after => $interval,
    cb    => sub { undef $reconnect_timer; $self->run(); }
  );
}                         #}}}

1;

=pod

=head1 NAME

Pogo::Worker::Connection

=head1 SYNOPSIS

 use Pogo::Worker::Connection;

=head1 DESCRIPTION

No user-serviceable parts inside.

=head1 SEE ALSO

L<Pogo::Dispatcher>, L<Pogo::Worker>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2010, Yahoo! Inc. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 AUTHORS

  Andrew Sloane <asloane@yahoo-inc.com>
  Michael Fischer <mfischer@yahoo-inc.com>
  Nicholas Harteau <nrh@yahoo-inc.com>
  Nick Purvis <nep@yahoo-inc.com>
  Robert Phan <rphan@yahoo-inc.com>

=cut

__END__

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
