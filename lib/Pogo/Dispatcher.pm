package Pogo::Dispatcher;

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

# dispatcher is our main server process
# . handles connections from workers
# . handles jsonrpc connections from the http api
# . fetch/store passwords

use strict;
use warnings;

use AnyEvent;
use AnyEvent::Socket qw(tcp_server);
use AnyEvent::TLS;
use Log::Log4perl qw(:easy);

use Pogo::Dispatcher::AuthStore;
use Pogo::Dispatcher::RPCConnection;
use Pogo::Dispatcher::WorkerConnection;

use constant MAX_WORKER_TASKS => 50;

our $instance;

sub instance
{
  return $instance if defined $instance;
  {
    my $class = shift;
    my $self  = shift;

    $self->{workers} = {
      idle => {},
      busy => {},
    };

    $self->{stats} = {
      hostname     => Sys::Hostname::hostname(),
      state        => 'connected',
      start_time   => time(),
      pid          => $$,
      tasks_failed => 0,
      tasks_run    => 0,
      workers_busy => 0,
      workers_idle => 0,
    };

    # set up ssl
    $self->{ssl_ctx} = AnyEvent::TLS->new(
      key_file                   => $self->{dispatcher_key},
      cert_file                  => $self->{dispatcher_cert},
      verify_require_client_cert => 1,
      verify                     => 0,
    ) or LOGDIE "failed to initialize SSL: $!";

    $instance = bless( $self, $class );
  }
  return $instance;
}

sub start
{
  my $self = shift;
  LOGDIE "dispatcher not yet initialized" unless defined $instance;

  # start these puppies up
  Pogo::Engine->init($self);
  Pogo::Dispatcher::AuthStore->init($self);

  # handle workers
  tcp_server(
    $instance->{bind_address},
    $instance->{worker_port},
    Pogo::Dispatcher::WorkerConnection->accept_handler,
    sub {
      INFO "listening for worker connections on " . $_[1] . ':' . $_[2];
      return 0;
    }
  );

#  # store/expire passwords
#  tcp_server(
#    $instance->{bind_address},
#    $instance->{authstore_port},
#    Pogo::Dispatcher::AuthStore->accept_handler,
#    sub {
#      INFO "listening for authstore connections on " .$_[1] . ':' . $_[2];
#      return 0;
#    }
#  );

  # accept rpc connections from the (local) http API
  tcp_server(
    '127.0.0.1',    # rpc server binds to localhost only
    $instance->{rpc_port},
    Pogo::Dispatcher::RPCConnection->accept_handler,
    sub {
      INFO "listening for rpc connections on " . $_[1] . ':' . $_[2];
      return 0;
    }
  );

  my $condvar = AnyEvent->condvar;

  $SIG{TERM} = sub { WARN "SIGTERM received"; $condvar->send(1); };
  $SIG{INT}  = sub { WARN "SIGINT received";  $condvar->send(1); };

  # periodically poll task queue for jobs
  my $poll_timer = AnyEvent->timer(
    after    => 1,
    interval => 1,
    cb       => \&_poll,
  );

  # periodically record stats
  my $stats_timer = AnyEvent->timer(
    after    => 1,
    interval => 5,
    cb       => \&_write_stats,
  );

  return $condvar->recv;
}

sub _poll
{
}

sub _write_stats
{
}

sub ssl_ctx
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  return $instance->{ssl_ctx};
}

sub idle_worker
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  my ($class, $worker) = @_;
  $worker->{tasks}--;
  if ($worker->{tasks} < MAX_WORKER_TASKS) {
    delete $instance->{workers}->{busy}->{ $worker->id };
    $instance->{workers}->{idle} ||= {};
    $instance->{workers}->{idle}->{ $worker->id } = $worker;
    DEBUG "marked worker idle: " . $worker->id;
  }
}

sub retire_worker
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  my ($class, $worker) = @_;
  delete $instance->{workers}->{idle}->{ $worker->id };
  delete $instance->{workers}->{busy}->{ $worker->id };
  DEBUG "retired worker: " . $worker->id;
}


1;

=pod

=head1 NAME

  Pogo::Dispatcher - Pogo's main()

=head1 SYNOPSIS

Pogo::Dispatcher sets up all the connection handlers via AnyEvent

=head1 DESCRIPTION

LONG_DESCRIPTION

=head1 METHODS

B<methodexample>

=over 2

methoddescription

=back

=head1 SEE ALSO

L<pogo-dispatcher>

=head1 COPYRIGHT

Apache 2.0

=head1 AUTHORS

  Andrew Sloane <asloane@yahoo-inc.com>
  Michael Fischer <mfischer@yahoo-inc.com>
  Nicholas Harteau <nrh@yahoo-inc.com>
  Nick Purvis <nep@yahoo-inc.com>
  Robert Phan <rphan@yahoo-inc.com>

=cut
