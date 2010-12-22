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

use 5.008;
use common::sense;

use Carp ();
use AnyEvent::Socket qw(tcp_server);
use AnyEvent::TLS;
use AnyEvent::HTTPD;
use AnyEvent;
use JSON::XS qw(encode_json);
use Log::Log4perl qw(:easy);
use Scalar::Util qw(refaddr);

use Pogo::Engine::Store qw(store);
use Pogo::Dispatcher::AuthStore;
use Pogo::Dispatcher::RPCConnection;
use Pogo::Dispatcher::WorkerConnection;

# this is maximum the number of queued up tasks to send to a worker, not the
# total concurrent limit (which is controlled in the worker itself)
use constant MAX_WORKER_TASKS => 50;

my $instance;

sub run    #{{
{
  Carp::croak "Server already running" if $instance;
  my $class = shift;
  $instance = { @_ };
  bless $instance, $class;

  $instance->{workers} = {
    idle => {},
    busy => {},
  };

  $instance->{stats} = {
    hostname     => Sys::Hostname::hostname(),
    state        => 'connected',
    start_time   => time(),
    pid          => $$,
    tasks_failed => 0,
    tasks_run    => 0,
    workers_busy => 0,
    workers_idle => 0,
  };

  # start these puppies up
  Pogo::Engine->init($instance);
  Pogo::Dispatcher::AuthStore->init($instance);

  # handle workers
  tcp_server(
    $instance->{bind_address},
    $instance->{worker_port} || Pogo::Dispatcher::WorkerConnection->DEFAULT_PORT,
    sub { Pogo::Dispatcher::WorkerConnection->accept(@_); },
    sub {
      local *__ANON__ = 'AE:cb:prepare_cb';
      INFO "Accepting worker connections on $_[1]:$_[2]";
    },
  );

  # accept rpc connections from the (local) http API
  # TODO: Deprecate this in favor of the HTTP service.
  tcp_server(
    '127.0.0.1',    # rpc server binds to localhost only
    $instance->{rpc_port} || Pogo::Dispatcher::RPCConnection->DEFAULT_PORT,
    sub { Pogo::Dispatcher::RPCConnection->accept(@_); },
    sub { local *__ANON__ = 'AE:cb:prepare_cb'; INFO "Accepting RPC connections on $_[1]:$_[2]"; },
  );

  # periodically poll task queue for jobs
  my $poll_timer = AnyEvent->timer(
    after    => 1,
    interval => 1,
    cb       => sub { poll(); },
  );

  # periodically record stats
  my $stats_timer = AnyEvent->timer(
    interval => 5,
    cb       => sub { _write_stats(); },
  );

  # Start event loop.
  AnyEvent->condvar->recv;
}    #}}}

sub poll
{
  foreach my $task ( store->get_children('/pogo/taskq') )
  {
    my @workers = values %{ $instance->{workers}->{idle} };
    if ( !scalar @workers )
    {
      DEBUG "task waiting but no idle workers connected...";

      #return;      # technically we don't need workers to do startjob.
    }

    # will we win the race to grab the task?
    my @req = split( /;/, $task );
    my ( $reqtype, $jobid, $host ) = @req;

    my $errc = sub {
      ERROR "Error executing @req: $@";
    };

    if ( $reqtype eq 'runhost' )
    {
      next if ( !scalar @workers );    # skip if we have no workers.
      next unless Pogo::Dispatcher::AuthStore->get($jobid);

      # skip for now if we have no passwords (yet?)

      if ( store->delete("/pogo/taskq/$task") )
      {
        my $job = Pogo::Engine->job($jobid);
        my $w   = $workers[ int rand( scalar @workers ) ];    # this is where we would include
                                                              # smarter logic on worker selection
        $w->start_task( $job, $host );
      }
    }
    elsif ( $reqtype eq 'startjob' )
    {

      if ( store->delete("/pogo/taskq/$task") )
      {
        my $job = Pogo::Engine->job($jobid);

        # TODO: handle error callback by halting job with an error
        $job->start( $errc, sub { } );
      }
    }
    elsif ( $reqtype eq 'continuejob' )
    {
      if ( store->delete("/pogo/taskq/$task") )
      {
        Pogo::Engine->job($jobid)->continue_deferred();
      }
    }
    elsif ( $reqtype eq 'resumejob' )
    {
      if ( store->delete("/pogo/taskq/$task") )
      {
        my $job = Pogo::Engine->job($jobid);
        $job->resume( 'job resumed by retry request', sub { $job->continue_deferred(); }, );
      }
    }
    else
    {
      ERROR "Unknown task '$task'";
    }
  }
  return;    # should not be reached;
}

sub _write_stats
{
  my $path  = '/pogo/stats/' . $instance->{stats}->{hostname} . '/current';
  my $store = Pogo::Engine->store;

  $instance->{stats}->{workers_busy} = scalar keys %{ $instance->{workers}->{busy} };
  $instance->{stats}->{workers_idle} = scalar keys %{ $instance->{workers}->{idle} };

  my @tasks = Pogo::Engine->listtaskq();

  $instance->{stats}->{tasks_queued} = scalar @tasks;
  $instance->{stats}->{last_update}  = time();

  if ( !$store->exists($path) )
  {
    DEBUG "creating new stats node";
    if ( !$store->exists( '/pogo/stats/' . $instance->{stats}->{hostname} ) )
    {
      $store->create( '/pogo/stats/' . $instance->{stats}->{hostname}, '' )
        or WARN "couldn't create stats/hostname node: " . $store->get_error;
    }
    $store->create_ephemeral( $path, '' )
      or WARN "couldn't create '$path' node: " . $store->get_error;
  }

  $store->set( $path, encode_json $instance->{stats} )
    or WARN "couldn't update stats node: " . $store->get_error;
}

# {{{ worker stuff

sub idle_worker
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  my ( $class, $worker ) = @_;
  if ( $worker->tasks < MAX_WORKER_TASKS )
  {
    delete $instance->{workers}->{busy}->{ $worker->id };
    $instance->{workers}->{idle}->{ $worker->id } = $worker;
    DEBUG sprintf( "Marked worker %s idle", $worker->id );
  }
}

sub retire_worker
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  my ( $class, $worker ) = @_;
  delete $instance->{workers}->{idle}->{ $worker->id };
  delete $instance->{workers}->{busy}->{ $worker->id };
  DEBUG sprintf( "Retired worker %s", $worker->id );
}

sub busy_worker
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  my ( $class, $worker ) = @_;
  $worker->{tasks}++;
  if ( $worker->{tasks} >= MAX_WORKER_TASKS )
  {
    delete $instance->{workers}->{idle}->{ $worker->id() };
    $instance->{workers}->{busy}->{ $worker->id() } = $worker;
    DEBUG "marked worker busy: " . $worker->id;
  }
}

# }}}
# {{{ accessors

sub dispatcher_cert
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  return $instance->{dispatcher_cert};
}

sub dispatcher_key
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  return $instance->{dispatcher_key};
}

sub worker_cert
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  return $instance->{worker_cert};
}

sub worker_script
{
  LOGDIE "Dispatcher not initialized yet" unless defined $instance;
  return $instance->{worker_script};
}

sub instance
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  return $instance;
}

# }}}

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

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
