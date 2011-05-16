package Pogo::Engine::Job;

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

use common::sense;

use Data::Dumper;
use List::Util qw(min max);
use AnyEvent;
use Data::Dumper;    # note we actually use this
use File::Slurp qw(read_file);
use JSON;
use Log::Log4perl qw(:easy);
use MIME::Base64 qw(encode_base64);
use Time::HiRes qw(time);
use JSON::XS qw(encode_json);

use Pogo::Common;
use Pogo::Engine::Store qw(store);
use Pogo::Engine::Job::Host;
use Pogo::Dispatcher::AuthStore;

# wait 100ms for other hosts to finish before finding the next set of
# runnable hosts
#our $UPDATE_INTERVAL = 0.10;
our $UPDATE_INTERVAL = 1;

# re-check constraints after 10 seconds if a job is unable to run more
# hosts
our $POLL_INTERVAL = 10;

# collect jobs to continue
my %CONTINUE_DEFERRED = ();

#$Data::Dumper::Deparse = 1;

# {{{ new
# Pogo::Engine::Job->new() creates a new job from the ether
# Pogo::Engine::Job->get(jobid) vivifies a job object from
# an existing jobid

sub new
{
  my ( $class, $args ) = @_;

  foreach my $opt (qw(target namespace user run_as password command timeout job_timeout))
  {
    LOGDIE "missing require job parameter '$opt'"
      unless exists $args->{$opt};
  }

  my $ns = $args->{namespace};

  my $jobstate = 'gathering';
  my $self     = {
    state  => $jobstate,
    _hosts => {},
  };

  my $jobpath = store->create_sequence( '/pogo/job/p', $jobstate )
    or LOGDIE "Unable to create job node: " . store->get_error_name;

  $jobpath =~ m{/(p\d+)$} or LOGDIE "malformed job path: $jobpath";
  $self->{id}   = $1;
  $self->{path} = $jobpath;
  $self->{ns}   = Pogo::Engine->namespace($ns);

  # TODO: ensure namespace exists

  store->create( "$jobpath/host", '' );
  store->create( "$jobpath/meta", '' );
  store->create( "$jobpath/log",  '' );
  store->create( "$jobpath/lock", '' );
  store->create( "$jobpath/slot", '' );

  bless $self, $class;

  my $target = delete $args->{target};

  # 'higher security tier' job arguments like encrypted passwords & passphrases
  # get stuffed into the distributed password store instead of zookeeper
  # (because we don't want them to show up in zk's disk snapshot)
  my $pw      = delete $args->{password};
  my $secrets = delete $args->{secrets};

  my $expire = $args->{job_timeout} + time() + 60;
  Pogo::Dispatcher::AuthStore->instance->store( $self->{id}, $pw, $secrets, $expire );

  # store all non-secure items in zk
  while ( my ( $k, $v ) = each %$args ) { $self->set_meta( $k, $v ); }
  $self->set_meta( 'target', encode_json($target) );

  Pogo::Engine->add_task( 'startjob', $self->{id} );

  return $self;
}

# }}}
# {{{ get

sub get
{
  my ( $class, $jobid ) = @_;
  my $jobpath = "/pogo/job/$jobid";

  my $state = store->get($jobpath);
  if ( !$state )
  {
    WARN "invalid state for jobid $jobid";
    return;
  }
  my $self = {
    id     => $jobid,
    path   => $jobpath,
    state  => $state,
    _hosts => {},
  };

  bless $self, $class;

  my $ns = $self->meta('namespace');

  # have we been purged?
  if ( !defined $ns )
  {
    WARN "request for non-existent jobid $jobid";
    return;
  }

  $self->{ns} = Pogo::Engine->namespace($ns);

  return $self;
}

# }}}
# {{{ meta
# cosmetically truncate a value for display
sub _shrink_meta_value
{
  my ( $s, $maxlen ) = @_;
  return $s if ( length($s) < $maxlen );
  my @v = split( m/,\s*/, $s );
  my $out = shift @v;

  while ( @v > 0 and length($out) < ( $maxlen - 13 ) )
  {
    $out .= ',' . shift @v;
  }

  if ( @v > 0 )
  {
    return substr( $out, 0, $maxlen - 13 ) . "...(" . ( scalar @v ) . " more)";
  }
  elsif ( length($out) > $maxlen )
  {
    return substr( $out, 0, $maxlen - 3 ) . "...";
  }
  return $out;
}

sub meta
{
  my ( $self, $k ) = @_;
  return store->get( $self->{path} . "/meta/$k" );
}

sub set_meta
{
  my ( $self, $k, $v ) = @_;
  my $node = $self->{path} . "/meta/$k";
  if ( !store->set( $node, $v ) )
  {
    return store->create( $node, $v );
  }
  return 1;
}

sub all_meta
{
  my ($self) = @_;
  return map { $_ => $self->meta($_) } store->get_children( $self->{path} . '/meta' );
}

sub info
{
  my ($self) = @_;
  if ( !exists $self->{_info} )
  {
    my %info = $self->all_meta;
    $info{start_time} = $self->start_time;
    $info{state}      = $self->{state};
    $info{jobid}      = $self->{id};
    $self->{_info}    = \%info;
  }
  return $self->{_info};
}

# }}}
# {{{ host stuff

sub host
{
  my ( $self, $hostname, $defstate ) = @_;
  if ( !exists $self->{_hosts}->{$hostname} )
  {
    $self->{_hosts}->{$hostname} = Pogo::Engine::Job::Host->new( $self, $hostname, $defstate );
  }
  return $self->{_hosts}->{$hostname};
}

sub has_host
{
  my ( $self, $host ) = @_;
  return store->exists( $self->{path} . "/host/$host" );
}

sub hosts
{
  my ($self) = @_;
  if ( !exists $self->{_hostlist} )
  {
    $self->{_hostlist} = [ map { $self->host($_) } store->get_children( $self->{path} . '/host' ) ];
  }
  return @{ $self->{_hostlist} };
}

sub hosts_in_slot
{
  my ( $self, $slot ) = @_;
  my $id = $slot->id;
  return map { $self->host($_) } store->get_children( $self->{path} . "/slot/$id" );
}

sub runnable_hosts
{
  my ($self) = @_;
  return grep { $_->is_runnable } $self->hosts;
}

sub unfinished_hosts
{
  my ($self) = @_;
  return grep { !$_->is_finished } $self->hosts;
}

sub unfinished_hosts_in_slot
{
  my ( $self, $slot ) = @_;
  return grep { !$_->is_finished } $self->hosts_in_slot($slot);
}

sub unsuccessful_hosts_in_slot
{
  my ( $self, $slot ) = @_;
  return grep { $_->is_failed && $_->is_finished } $self->hosts_in_slot($slot);
}

sub running_hosts
{
  my ($self) = @_;
  return grep { $_->is_running } $self->hosts;
}

sub failed_hosts
{
  my ($self) = @_;
  return grep { $_->is_failed } $self->hosts;
}

sub runnable_hostinfo
{
  my ($self) = @_;
  my @runnable = $self->runnable_hosts;
  return { map { $_->name, $_->info } @runnable };
}

sub start_task
{
  my ( $self, $hostname, $output_url ) = @_;
  DEBUG $self->id . " task for $hostname started; output=$output_url";
  my $host = $self->host($hostname);

  $host->add_outputurl($output_url);

  # there is a race condition here: it's possible that the host is done already
  # and was reported done to another dispatcher before we process this message.
  # in that case, we want to set the outputurl in the log without changing the
  # state.
  my ( $state, $ext ) = $host->state;
  if ( $state eq 'ready' )
  {
    # normally, this is what happens
    $self->set_host_state( $host, 'running', 'started', output => $output_url );
  }
  else
  {
    # craft a redundant host state log message which just updates the output url
    $self->log( 'hoststate', { host => $host->{name}, state => $state, output => $output_url },
      $ext );
  }
}

sub retry_task
{
  DEBUG Dumper [@_];
  my ( $self, $hostname ) = @_;
  die "no host $hostname in job" if ( !$self->has_host($hostname) );
  my $host = $self->host($hostname);
  if ( $host->state eq 'failed' or $host->state eq 'finished' )
  {
    my $hinfo = $host->info;
    if ( !defined $hinfo )
    {
      LOGDIE "Hostinfo missing for $hostname; cannot retry\n";
    }
    if ( defined $hinfo->{error} )
    {
      LOGDIE "Not retrying $hostname: " . $hinfo->{error} . "\n";
    }
    $self->set_host_state( $host, 'waiting', 'retry requested' );
    return 1;
  }
  else
  {
    return 0;
  }
}

sub finish_task
{
  my ( $self, $hostname, $exitstatus, $msg ) = @_;
  DEBUG "host $hostname exited $exitstatus";
  my $host = $self->host($hostname);

  # TODO: set end time meta value on host

  # TODO: if all workers are idle and the job isn't finished, mark it stuck
  # also check for deadlocks somehow
  Pogo::Dispatcher->instance()->{stats}->{tasks_run}++;

  if ( $exitstatus == 0 )
  {
    $self->set_host_state( $host, 'finished', $msg || 'ok', exitstatus => 0 );
    $self->release_host( $host, sub { $self->continue_deferred() } );
  }
  else
  {
    # TODO: we need to find extended status messages here once we get the pogo-worker stuff going
    $self->set_host_state(
      $host, 'failed',
      length($msg) || "exited with status $exitstatus",
      exitstatus => $exitstatus,
    );
    Pogo::Dispatcher->instance()->{stats}->{tasks_failed}++;

    if ( !$self->is_running )
    {
      $self->release_host( $host, sub { } );
      return;
    }
    $self->continue_deferred();
  }
}

sub resume
{
  my ( $self, $reason, $cb ) = @_;
  return $cb->() if ( $self->is_running );

  my @failed          = $self->failed_hosts;
  my @failed_names    = map { $_->name } @failed;
  my %failed_hostinfo = map { $_->name, $_->info } @failed;
  my $ns              = $self->namespace;

  my $errc = sub { ERROR $@ };

  # re-lock all slots for any failed hosts in the job
  $ns->fetch_all_slots(
    $self,
    \%failed_hostinfo,
    $errc,
    sub {
      my ( $allslots, $hostslots ) = @_;

      # reserve a slot for all our failed hosts
      foreach my $hostname (@failed_names)
      {
        map { $_->reserve( $self, $hostname ) } @{ $hostslots->{$hostname} };
      }

      $self->set_state( 'running', $reason );
      $cb->();
    }
  );
}

# }}}
# {{{ slot stuff

sub is_slot_done
{
  my ( $self, $slot ) = @_;
  return scalar $self->unfinished_hosts_in_slot($slot) == 0;
}

sub is_slot_successful
{
  my ( $self, $slot ) = @_;
  return scalar $self->unsuccessful_hosts_in_slot($slot) == 0;
}

sub init_slot
{
  my ( $self, $slot, $hostname ) = @_;
  my $id = $slot->id;
  store->create( $self->{path} . "/slot/$id",           '' );
  store->create( $self->{path} . "/slot/$id/$hostname", '' );
}

sub unlock_all
{
  my $self = shift;
  my $ns   = $self->namespace;

  my $joblock = $self->lock('Pogo::Engine::Job::unlock_all');
  $ns->unlock_job($self);
  $self->unlock($joblock);
}

# }}}
# {{{ job state stuff
sub is_running
{
  my $self  = shift;
  my $state = $self->state;
  return ( $state eq 'running' or $state eq 'gathering' )
    ? 1
    : 0;
}

sub halt
{
  my ( $self, $reason ) = @_;
  $reason ||= 'halted by user';    # TODO: which user?
  DEBUG "halting " . $self->id;
  $self->set_state( 'halted', $reason );
  foreach my $host ( $self->unfinished_hosts )
  {
    if ( !$host->is_running )
    {
      $self->set_host_state( $host, 'halted', 'job halted', $reason );
    }
  }
  Pogo::Dispatcher->purge_queue( $self->id );
  $self->unlock_all();
}

# }}}
# {{{ timeout

sub start_job_timeout
{
  my $self    = shift;
  my $jobid   = $self->id;
  my $timeout = $self->job_timeout;

  DEBUG "starting $jobid timeout timer for $timeout sec";
  my $timeout_tmr;
  $timeout_tmr = AnyEvent->timer(
    after => $timeout,
    cb    => sub {
      local *__ANON__ = 'AE:cb:job_timeout';
      my $job = Pogo::Engine->job($jobid);

      if ( $job->is_running )
      {
        $job->halt('timeout reached');
      }

      # archiving goes here

      undef $timeout_tmr;
    }
  );
}

# }}}
# {{{ various accessors

sub password                { return $_[0]->_get_secrets()->[0]; }
sub secrets                 { return $_[0]->_get_secrets()->[1]; }
sub namespace               { return $_[0]->{ns} }
sub id                      { return $_[0]->{id} }
sub user                    { return $_[0]->meta('user'); }
sub run_as                  { return $_[0]->meta('run_as'); }
sub timeout                 { return $_[0]->meta('timeout'); }
sub job_timeout             { return $_[0]->meta('job_timeout'); }
sub retry                   { return $_[0]->meta('retry'); }
sub command                 { return $_[0]->meta('command'); }
sub concurrent              { return $_[0]->meta('concurrent'); }
sub state                   { return store->get( $_[0]->{path} ); }

# Returns the transform for a given root type
# root_type precedence :
# root_type param in client.conf >
# root_type param in namespace >
# zookeeper /pogo/root/default
sub command_root_transform
{ 
  my $root = $_[0]->meta('root_type'); 
  $root = $_[0]->{ns}->get_conf->{globals}->{root_type} unless $root;
  $root = store->get("/pogo/root/default") unless $root;
  return store->get("/pogo/root/" . $root);
}
  
sub set_state
{
  my ( $self, $state, $msg, @extra ) = @_;
  $self->{state} = $state;
  store->set( $self->{path}, $state );
  $self->log( 'jobstate', { state => $state, @extra }, $msg );
}

sub set_host_state
{
  my ( $self, $host, $state, $msg, @extra ) = @_;
  if ( $host->set_state( $state, $msg, @extra ) )
  {
    @extra = map { _shrink_meta_value( $_, 150 ) } @extra;
    $self->log( 'hoststate', { host => $host->{name}, state => $state, @extra }, $msg );
  }
}

# }}}
# {{{ start

# Job->start is called from _poll when 'startjob' tasks are encountered.
sub start
{
  my ( $self, $errc, $cont ) = @_;

  my $target     = decode_json( $self->meta('target') );
  my $ns         = $self->namespace;
  my $concurrent = $self->concurrent;
  my $joblock    = $self->lock("Pogo::Engine::Job::start:before_hostinfo");

  $self->set_state( 'gathering', 'job created; fetching host info', target => $target );
  INFO "starting job " . $self->id;

  my $all_host_meta = {};
  my @dead_hosts    = ();

  my $flat_targets = $ns->expand_targets($target);

  eval {
    # constrained codepath
    # fetch all meta (apps+envs) before we add to the job

    if ( !defined $concurrent )
    {
      DEBUG "we are constrained.";

      my $fetch_errc = sub {
        local *__ANON__ = 'AE:cb:fetch_target_meta:errc';
        ERROR $self->id . ": unable to obtain meta info for target: $@";
        $self->set_state( 'halted', "unable to obtain meta info for target: $@" );
        return $errc->();
      };

      my $fetch_cont = sub {
        my( $hinfo ) = @_;
        local *__ANON__ = 'AE:cb:fetch_target_meta:cont';
        DEBUG $self->id . ": adding hosts";
        DEBUG $self->id . ": computing slots";
        DEBUG sub { "Calling fetch_runnable_hosts with " . Dumper($hinfo) };
        $ns->fetch_runnable_hosts( $self, $hinfo, $errc, $cont );
        DEBUG "Job after fetch_runnable_hosts: ", $self;
      };

      DEBUG "Calling fetch_target_meta for @$flat_targets";
      $ns->fetch_target_meta( $flat_targets, $ns->name, $fetch_errc, 
                              $fetch_cont );
      DEBUG "After fetch_target_meta";
      return 1;
    }
    else    # concurrent codepath
    {
      DEBUG "We are concurrent, flat targets are: @$flat_targets";
      foreach my $hostname (@$flat_targets)
      {
        my $host = $self->host( $hostname, 'waiting' );

        # note that i think we should probably store host meta here anyway
        # since we don't want a concurrent and a constrained job to overlap
        # and allow too many hosts down
        # lack of hinfo just isn't an error in that case

        my $hmeta = { _concurrent => $concurrent };
        $host->set_hostinfo($hmeta);
        $all_host_meta->{$hostname} = $hmeta;
      }
      $self->set_state( 'running', "constraints computed" );
      $self->start_job_timeout();
    }
  };

  if ($@)
  {
    ERROR $@;
    $self->unlock($joblock);
    $errc->($@);
  }

  $self->unlock($joblock);

  $ns->fetch_all_slots(
    $self,
    $all_host_meta,
    $errc,
    sub {
      my ( $allslots, $hostslots ) = @_;
      local *__ANON__ = 'start:fetch_all_slots:cont';

      # create pre-computed slot lookups for all hosts in the job
      while ( my ( $hostname, $slots ) = each %$hostslots )
      {
        map { $self->init_slot( $_, $hostname ) } @$slots;
      }

      # reserve a slot for all our dead hosts
      foreach my $hostname (@dead_hosts)
      {
        map { $_->reserve( $self, $hostname ) } @{ $hostslots->{$hostname} };
      }

      # continue the job
      $self->continue( $all_host_meta, $errc, $cont );
    }
  );
}

# release_host is called on successful exit to free up slots for subsequent hosts
# this might either be moved into a namespace method or a host method with
# continue_deferred being a continuation but whatever

sub release_host
{
  my ( $self, $host, $cont ) = @_;

  # release slots for this host
  my $ns       = $self->namespace;
  my %hostinfo = ( $host->name() => $host->info );
  my $errc     = sub { ERROR $?; };

  $ns->fetch_all_slots(
    $self,
    \%hostinfo,
    $errc,
    sub {
      my ( $allslots, $hostslots ) = @_;
      while ( my ( $hostname, $slots ) = each %$hostslots )
      {
        map { DEBUG "releasing $_->{path} for $hostname"; $_->unreserve( $self, $hostname ) }
          @$slots;
      }

      return $cont->();
    }
  );
}

# continue_deferred queues up continue requests on task completion
# we do this to avoid running continue() (expensive, walks zk) on every
# completed task, instead batching them up in $POLL_INTERVAL intervals
#
# inputs: none
# outputs: none
# side effects:
#   - manipulates %CONTINUED_DEFERRED
#   - sets up timer to call $job->continue() wkth a continuation
#   to...itself! (continue_deferred).
# so there's a loop of:
#   - add_task
#   - finish_task
#   - continue_deferred
#   - continue
#   - back to add_task

sub continue_deferred
{
  my ($self) = @_;
  return if ( exists $CONTINUE_DEFERRED{ $self->id } );

  if ( !$self->is_running )
  {
    DEBUG $self->id . " is $self->{state}; not continuing";
    return;
  }

  my $errc = sub { ERROR $?; };
  my $cont = sub {
    my ( $nqueued, $nwaiting ) = @_;

    if ( $nqueued == 0 && $nwaiting > 0 )
    {

      # we aren't able to do anything right now, try again later.

      my $tmr;
      $tmr = AnyEvent->timer(
        after => $POLL_INTERVAL,
        cb    => sub {
          undef $tmr;
          $self->continue_deferred();
        }
      );
    }
  };

  my $tmr;
  $tmr = AnyEvent->timer(
    after => $UPDATE_INTERVAL,
    cb    => sub {
      $tmr = undef;
      delete $CONTINUE_DEFERRED{ $self->id };
      return $self->continue( $self->runnable_hostinfo, $errc, $cont );
    }
  );

  return $CONTINUE_DEFERRED{ $self->id } = 1;
}

sub continue
{
  my ( $self, $all_host_meta, $errc, $cont ) = @_;

  if ( !$self->is_running )
  {
    DEBUG "job $self->{id} is $self->{state}; not continuing job";
    return;
  }

  # scan the entire hostlist for hosts that can be run and add
  # tasks for them; this will have to be repeated
  DEBUG "continuing job $self->{id}";
  my $ns = $self->namespace;

  $ns->fetch_runnable_hosts(
    $self,
    $all_host_meta,
    $errc,
    sub {
      local *__ANON__ = 'continue:fetch_runnable_hosts:cont';
      my ( $runnable, $unrunnable, $global_lock ) = @_;
      my ( $nqueued, $nwaiting ) = ( 0, 0 );

      foreach my $hostname ( sort { $a cmp $b } @$runnable )
      {
        DEBUG "enqueueing $hostname";
        $self->set_host_state( $self->host($hostname), 'ready', 'preparing to connect...' );
        Pogo::Engine->add_task( 'runhost', $self->{id}, $hostname );
        $nqueued++;
      }

      while ( my ( $hostname, $blocker ) = each(%$unrunnable) )
      {
        DEBUG "not runnable yet: $hostname - $blocker";
        $self->set_host_state( $self->host($hostname), 'waiting', "waiting for $blocker" );
        $nwaiting++;
      }

      store->unlock($global_lock);

      # are we done?
      if ( scalar $self->unfinished_hosts == 0 )
      {
        DEBUG "job $self->{id} appears to be finished";
        $self->set_state( 'finished', 'no more hosts to run' );
        $self->unlock_all();
        return;
      }

      DEBUG "nqueued=$nqueued nwaiting=$nwaiting";

      if ( $nqueued == 0 && $nwaiting > 0 )
      {

        # are any hosts running/ready at all?
        if ( scalar $self->running_hosts == 0 )
        {
          DEBUG "job $self->{id} appears to be stuck";
          $self->set_state( 'deadlocked', 'unable to run more hosts due to failures' );

          # TODO: mass-change 'waiting' hosts to 'deadlocked';
          $self->unlock_all();
          return;
        }
      }

      return $cont->( $nqueued, $nwaiting );
    }
  );
}

# }}}
# {{{ locking

sub lock
{
  my ( $self, $source ) = @_;
  LOGDIE "source not supplied to job lock request" if ( !defined $source );
  store->_lock_write( $self->{path} . "/lock", $source, 60000 )
    or LOGDIE "timed out locking $self->{id}\n";
}

sub unlock { store->delete( $_[1] ); }

# }}}
# {{{ logging

sub log
{
  my ( $self, @stuff ) = @_;
  my $t = time();
  my $entry = encode_json( [ $t, @stuff ] );
  store->create_sequence( $self->{path} . '/log/l', $entry )
    or ERROR "couldn't create log sequence: " . store->get_error_name;
}

# determine job start time by the first log entry's timestamp
# TODO: what's the retval when the first log entry isn't valid JSON?
sub start_time
{
  my ($self) = @_;
  if ( my $data = store->get( $self->{path} . '/log/' . _lognode(0) ) )
  {
    return eval { $data = decode_json $data; return $data->[0]; };
  }
}

sub _lognode
{
  return sprintf( "l%010d", $_[0] );
}

sub cur_logidx
{
  my ($self) = @_;
  return store->get_children_version( $self->{path} . '/log' );
}

sub read_log
{
  my ( $self, $offset, $limit ) = @_;
  my $path = $self->{path} . '/log/';

  my @log;

  $offset ||= 0;
  $limit  ||= -1;

  while ( $limit-- && ( my $data = store->get( $path . _lognode($offset) ) ) )
  {
    my $logentry = eval { decode_json($data); };
    if ($@)
    {
      push @log,
        [
        $offset, time(), 'readerror',
        { error => $@ },
        "error reading log entry at offset $offset",
        ];
      $offset++;
    }
    else
    {
      push @log, [ $offset++, @$logentry ];
    }
  }
  return @log;
}

# }}}
# {{{ job snapshotting

sub parse_log
{
  my ( $self, $limit, $offset ) = @_;

  my $path = $self->{path} . '/log/';
  my $snap = {};

  # NEED MORE MOJO HERE
  my $update_state = sub {
    my ( $ts, $obj, $args, $msg ) = @_;

    $snap->{$obj} ||= {};

    while ( my ( $k, $v ) = each %$args )
    {
      if ( $k eq 'state' )
      {
        if ( $v eq 'running' )
        {

          # create new run with start time @ $ts
          # each block in runs has:
          #   s => start timestamp
          #   o => output url
          #   e => end timestamp
          #   x => exit code
          #   m => exit msg
          push @{ $snap->{$obj}->{runs} }, { s => $ts, o => $args->{output} };
        }
        elsif ( Pogo::Engine::Job::Host::_is_finished($v) )
        {

          # mark end time of last run
          $snap->{$obj}->{runs} ||= [ {} ];
          $snap->{$obj}->{runs}->[-1]->{e} = $ts;
        }
        $snap->{$obj}->{$k} = $v;
      }
      elsif ( $k eq 'exitstatus' )
      {
        $snap->{$obj}->{runs} ||= [ {} ];
        $snap->{$obj}->{runs}->[-1]->{x} = $v;
        $snap->{$obj}->{runs}->[-1]->{m} = $msg;
      }
      elsif ( $k eq 'output' )
      {

        # this might get parsed before state => running, so it's handled there
        if ( $args->{state} ne 'running' )
        {

          # this resulted from an out-of-order log message, so we need to
          # estimate the start time
          $snap->{$obj}->{runs} ||= [ {} ];
          $snap->{$obj}->{runs}->[-1]->{s} = $ts;
          $snap->{$obj}->{runs}->[-1]->{o} = $v;
          my $e = $snap->{$obj}->{runs}->[-1]->{e};
          if ( defined $e && $e < $ts )
          {
            $snap->{$obj}->{runs}->[-1]->{s} = $e;
          }
        }
      }
      else
      {
        $snap->{$obj}->{$k} = $v;
      }
    }
    $snap->{$obj}->{msg} = $msg;
  };

  while ( $limit-- && ( my $data = store->get( $path . _lognode( $offset++ ) ) ) )
  {
    my $logentry = eval { JSON::from_json($data); };

    # TODO: shouldn't this be reported or something?
    next if $@;
    my ( $ts, $type, $state, $msg ) = @$logentry;
    $update_state->( $ts, 'job',          $state, $msg ) if ( $type eq 'jobstate' );
    $update_state->( $ts, $state->{host}, $state, $msg ) if ( $type eq 'hoststate' );
  }

  return $snap;
}

sub snapshot
{
  my ( $self, $offset ) = @_;

  my $idx      = $self->cur_logidx;
  my $path     = $self->{path};
  my $cacheidx = store->get( $path . '/_snapidx' );
  $offset ||= 0;

  # do we have a cached snapshot, and is it a) current and b) actually existent
  # and c) of the latest format?
  if ( $offset == 0
    && defined $cacheidx
    && $cacheidx == $idx
    && store->exists( $path . '/_snapshot0' )
    && store->get( $path . '/_snapver' ) eq '1' )
  {
    my $snap = '';
    my $i    = 0;
    while ( defined( my $data = store->get( $path . "/_snapshot$i" ) ) )
    {
      $snap .= $data;
      $i++;
    }
    return ( $cacheidx, $snap );
  }

  my $snap = JSON::to_json( $self->parse_log( $idx - $offset, $offset ) );

  if ( $offset == 0 )
  {
    # store the snapshot in 1-meg chunks (ZK can't store >1 meg in a node)
    # _snapshot0 .. _snapshotN
    my ( $i, $off, $snaplen ) = ( 0, 0, length($snap) );
    while ( ( my $len = min( 524288, $snaplen - $off ) ) > 0 )
    {
      store->create( $path . "/_snapshot$i", substr( $snap, $off, $len ) );
      $off += $len;
      $i++;
    }
    store->create( $path . '/_snapidx', $idx );
    store->create( $path . '/_snapver', '1' );
  }

  return ( $idx, $snap );
}

# }}}
# {{{ worker assembly - wow this is awkward

sub worker_command
{
  my $self        = shift;
  my %meta        = $self->all_meta;
  my $exe         = delete $meta{exe_data} || '';
  my $worker_stub = read_file( Pogo::Dispatcher->instance->worker_script )
    . encode_perl(
    { job => $self->id,
      api => Pogo::Engine->instance()->{api_uri},
      %meta
    }
    );

  # pad the worker stub so we don't need to decode the exe just to re-encode it
  if ($exe)
  {
    $worker_stub .= ' ' x ( 2 - length($worker_stub) % 3 );
    $worker_stub .= "\n";
  }

  return [ 'POGOATTACHMENT!' . encode_base64($worker_stub) . $exe ];
}

# }}}
# {{{ misc helper

sub _get_secrets
{
  my ($self) = @_;
  my $entry = Pogo::Dispatcher::AuthStore->get( $self->{id} );
  LOGDIE "No password entry found for job $self->{id}!" if ( !$entry );
  return $entry;
}

# ugh this bugs me
sub encode_perl
{
  local $Data::Dumper::Terse  = 1;
  local $Data::Dumper::Indent = 0;
  local $Data::Dumper::Purity = 1;
  local $Data::Dumper::Useqq  = 1;
  return Dumper(@_);
}

# these two might be unused?
sub _get
{
  my ( $self, $k ) = @_;
  return store->get( $self->{path} . '/' . $k );
}

sub _set
{
  my ( $self, $k, $v ) = @_;
  my $node = $self->{path} . '/' . $k;

  store->create( $node, $v )
    or LOGDIE "error creating $node: " . store->get_error_name;
}

# }}}

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

  Andrew Sloane <andy@a1k0n.net>
  Michael Fischer <michael+pogo@dynamine.net>
  Mike Schilli <m@perlmeister.com>
  Nicholas Harteau <nrh@hep.cat>
  Nick Purvis <nep@noisetu.be>
  Robert Phan <robert.phan@gmail.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
