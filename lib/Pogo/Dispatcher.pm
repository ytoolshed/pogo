package Pogo::Dispatcher;

# Copyright (c) 2010-2011 Yahoo! Inc. All rights reserved.
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

use Data::Dumper;

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
use constant MAX_WORKER_TASKS => 20;

my $instance;

sub run    #{{
{
  Carp::croak "Server already running" if $instance;
  my $class = shift;
  $instance = {@_};
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
  load_root_transform();

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
    interval => 10,
    cb       => sub { poll(); },
  );

  # periodically record stats
  my $stats_timer = AnyEvent->timer(
    interval => 5,
    cb       => sub { write_stats(); },
  );

  # Start event loop.
  AnyEvent->condvar->recv;
}

# }}}

# Loads root transforms from plugins into Zookeeper
sub load_root_transform
{
  eval { load_root_plugin(); };
  LOGDIE $@ if $@;
  my $path = "/pogo/root/";
  while ( my ( $k, $v ) = each( %{ $instance->{root} } ) )
  {
    store->delete( $path . $k );
    store->create( $path . $k, $v )
      or LOGDIE "couldn't create '$path' node: " . store->get_error_name;
  }
}

# Look into Pogo/Plugin/Root for root transform plugins
# The plugins should have the following interface
# sub root_type : returns root type string
# sub transform : return transform string
# sub priority  : return priority integer
# Creates a hash of root_type:transform from the plugins
# along with an entry default:root_type
# which is the root_type with highest priority
sub load_root_plugin
{
  # holds name and priority of default root
  my @default_root;

  foreach my $root_plugin (
    Pogo::Plugin->load_multiple( 'Root', { required_methods => [ 'root_type', 'transform' ] } ) )
  {
    DEBUG "processing Root type: " . $root_plugin->root_type();

    # add this root transform to our list
    $instance->{root}->{ $root_plugin->root_type() } = $root_plugin->transform();
  }

  # record our default root type, which is still stored in Pogo::Plugin
  $instance->{root}->{default} =
    Pogo::Plugin->load( 'Root', { required_methods => [ 'root_type', 'transform' ] } )->root_type();
}

sub purge_queue
{
  my ( $class, $jobid ) = @_;
  my @tasks = store->get_children('/pogo/taskq');
  foreach my $task (@tasks)
  {
    my ( $reqtype, $task_jobid, $host ) = split( /;/, $task );
    if ( $jobid eq $task_jobid && $reqtype eq 'runhost' )
    {
      store->delete("/pogo/taskq/$task");
      DEBUG "purged $task";
    }
  }
}

sub poll
{
  my @tasks = store->get_children('/pogo/taskq');
  foreach my $task (@tasks)
  {
    my @workers = values %{ $instance->{workers}->{idle} };
    if ( scalar @workers <= 0 )
    {
      DEBUG sprintf "%d task%s waiting but no idle workers connected...",
        scalar @tasks,
        scalar @tasks > 1 ? 's' : '';
      # we'll bail out here and retry the next poll interval
      #last;
      next;
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

      # skip for now if we have no passwords (yet?)
      if ( !Pogo::Dispatcher::AuthStore->get($jobid) )
      {
        DEBUG "skipping task for $jobid, no secrets found";
        next;
      }

      if ( store->delete("/pogo/taskq/$task") )
      {
        my $job = Pogo::Engine->job($jobid);
        my $w   = $workers[ int rand( scalar @workers ) ];    # this is where we would include
                                                              # smarter logic on worker selection
        $w->queue_task( $job, $host );
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

sub write_stats
{
  my $path  = '/pogo/stats/' . $instance->{stats}->{hostname} . '/current';
  my $store = Pogo::Engine->store;

  $instance->{stats}->{workers_busy} = [ sort keys %{ $instance->{workers}->{busy} } ];
  $instance->{stats}->{workers_idle} = [ sort keys %{ $instance->{workers}->{idle} } ];

  my @tasks = Pogo::Engine->listtaskq();

  $instance->{stats}->{tasks_queued} = scalar @tasks;
  $instance->{stats}->{last_update}  = time();

  if ( !$store->exists($path) )
  {
    DEBUG "creating new stats node";
    if ( !$store->exists( '/pogo/stats/' . $instance->{stats}->{hostname} ) )
    {
      $store->create( '/pogo/stats/' . $instance->{stats}->{hostname}, '' )
        or WARN "couldn't create stats/hostname node: " . $store->get_error_name;
    }
    $store->create_ephemeral( $path, '' )
      or WARN "couldn't create '$path' node: " . $store->get_error_name;
  }

  $store->set( $path, encode_json $instance->{stats} )
    or WARN "couldn't update stats node: " . $store->get_error_name;
}

# {{{ worker stuff

sub idle_worker
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  my ( $class, $worker ) = @_;
  if ( delete $instance->{workers}->{busy}->{ $worker->id } )
  {
    $instance->{workers}->{idle}->{ $worker->id } = $worker;
    DEBUG sprintf "marked worker %s idle (%d)", $worker->id, $worker->active_tasks;
    write_stats();
  }
}

sub busy_worker
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  my ( $class, $worker ) = @_;
  if ( $worker->active_tasks >= MAX_WORKER_TASKS )
  {
    delete $instance->{workers}->{idle}->{ $worker->id };
    $instance->{workers}->{busy}->{ $worker->id } = $worker;
    DEBUG sprintf "marked worker %s busy (%d)", $worker->id, $worker->active_tasks;
    write_stats();
  }
}

sub enlist_worker
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  my ( $class, $worker ) = @_;
  if ( !defined $instance->{workers}->{idle}->{ $worker->id } )
  {
    $instance->{workers}->{idle}->{ $worker->id } = $worker;
    DEBUG sprintf( "enlisted worker %s", $worker->id );
    write_stats();
  }
  else
  {
    ERROR "trying to enlist already-enlisted worker? " . $worker->id;
  }
}

sub retire_worker
{
  LOGDIE "dispatcher not yet initialized" unless defined $instance;
  my ( $class, $worker ) = @_;
  delete $instance->{workers}->{idle}->{ $worker->id };
  delete $instance->{workers}->{busy}->{ $worker->id };
  DEBUG sprintf( "retired worker %s", $worker->id );
  write_stats();
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

sub target_keyring
{
  return $instance->{target_keyring};
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

  Andrew Sloane <andy@a1k0n.net>
  Michael Fischer <michael+pogo@dynamine.net>
  Mike Schilli <m@perlmeister.com>
  Nicholas Harteau <nrh@hep.cat>
  Nick Purvis <nep@noisetu.be>
  Robert Phan <robert.phan@gmail.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
