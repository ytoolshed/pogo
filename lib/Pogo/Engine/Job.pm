package Pogo::Engine::Job;

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

#use File::Slurp qw(read_file);
#use List::Util qw(min max);
#use MIME::Base64 qw(encode_base64);
#use Time::HiRes qw(time);
use AnyEvent;
use Data::Dumper;
use JSON;
use Log::Log4perl qw(:easy);

use Pogo::Common;
use Pogo::Engine;
use Pogo::Engine::Store qw(store);
use Pogo::Engine::Job::Host;

# wait 100ms for other hosts to finish before finding the next set of
# runnable hosts
our $UPDATE_INTERVAL = 0.10;

# re-check constraints after 10 seconds if a job is unable to run more
# hosts
our $POLL_INTERVAL = 10;

sub new
{
  my ($class, $args) = @_;

  foreach my $opt (qw(target namespace user run_as password command timeout job_timeout pkg_passwords))
  {
    LOGDIE "missing require job parameter '$opt'"
      unless exists $args->{$opt};
  }

  my $ns = $args->{namespace};

  my $jobstate = 'gathering';
  my $self = {
    state => $jobstate,
    _hosts => {},
  };

  my $jobpath = store->create_sequence( '/pogo/job/p', $jobstate )
    or LOGDIE "Unable to create job node: " . store->get_error_name;

  $jobpath =~ m{/(p\d+)$} or LOGDIE "malformed job path";
  $self->{id} = $1;
  $self->{path} = $jobpath;
  $self->{ns} = Pogo::Engine->namespace($ns);

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
  my $pw     = delete $args->{password};
  my $pp     = delete $args->{pkg_passwords};
  my $expire = $args->{job_timeout} + time();

  my $cv = AnyEvent->condvar;
  Pogo::Engine->rpcclient(
    [ 'storepw', $self->{id}, $pw, $pp, $expire ],
    sub {
      my ( $ret, $err ) = @_;
      if (! defined $ret )
      {
        WARN "error storing passwords for job $self->{id}: $err";
      }
      else
      {
        INFO "passwords for $self->{id} stored to local dispatcher";
      }
      $cv->send(1);
    }
    );
  $cv->recv();

  # store all non-secure items in zk
  while (my ($k, $v) = each %$args ) { $self->set_meta( $k, $v ); }
  $self->set_meta( 'target', to_json($target));

  Pogo::Engine->add_task( 'startjob', $self->{id} );

  return $self;
}

# Pogo::Engine::Job->new() creates a new job from the ether
# Pogo::Engine::Job->get(jobid) vivifies a job object from
# an existing jobid
sub get
{
  my ( $class, $jobid ) = @_;
  my $jobpath = "/pogo/job/$jobid";

  my $state = store->get($jobpath);
  if (!$state)
  {
    WARN "invalid state for jobid $jobid";
    return;
  }
  my $self = {
    id => $jobid,
    path => $jobpath,
    state => $state,
  };

  bless $self, $class;

  my $ns = $self->meta('namespace');

  # have we been purged?
  if (!defined $ns)
  {
    WARN "request for non-existent jobid $jobid";
    return;
  }

  $self->{ns} = Pogo::Engine->namespace($ns);

  return $self;
}

sub _get
{
  my ($self, $k) = @_;
  return store->get( $self->{path} . '/' . $k );
}

sub _set
{
  my ($self, $k, $v) = @_;
  my $node = $self->{path} . '/' . $k;

  store->create( $node, $v )
    or LOGDIE "error creating $node: " . store->get_error_name;
}

# cosmetically truncate a value for display
sub _shrink_meta_value
{
  my ($s, $maxlen ) = @_;
  return $s if (length($s) < $maxlen);
  my @v = split( m/,\s*/, $s );
  my $out = shift @v;

  while (@v > 0 and length($out) < ( $maxlen - 13 ) )
  {
    $out .= ',' . shift @v;
  }

  if (@v > 0)
  {
    return substr( $out, 0, $maxlen - 13) . "...(" . (scalar @v) . " more)";
  }
  elsif (length($out) > $maxlen )
  {
    return substr( $out, 0, $maxlen - 3 ) . "...";
  }
  return $out;
}

sub meta
{
  my ($self, $k) = @_;
  return store->get( $self->{path} . "/meta/$k" );
}

sub set_meta
{
  my ($self, $k, $v) = @_;
  my $node = $self->{path} . "/meta/$k";
  if (!store->set( $node, $v))
  {
    return store->create($node, $v );
  }
  return 1;
}

sub all_meta
{
  my ($self) = @_;
  return map { $_ => $self->meta($_) } store->get_children( $self->{path} . '/meta' );
}

# determine job start time by the first log entry's timestamp
sub start_time
{
  my ($self) = @_;
  if (my $data = store->get( $self->{path} . '/log/' . _lognode(0)))
  {
    return eval { $data = from_json $data; return $data->[0]; };
  }
}

sub _lognode
{
  return sprintf( "l%010d", $_[0] );
}

sub info
{
  my ($self) = @_;
  if (!exists $self->{_info})
  {
    my %info = $self->all_meta;
    $info{start_time} = $self->start_time;
    $info{state} = $self->{state};
    $self->{_info} = \%info;
  }
  return $self->{_info};
}

sub host
{
  my ($self, $hostname, $defstate) = @_;
  if (!exists $self->{_hosts}->{$hostname})
  {
    $self->{_hosts}->{$hostname} = Pogo::Engine::Job::Host->new( $self, $hostname, $defstate );
  }
  return $self->{_hosts}->{$hostname};
}

sub has_host
{
  my ($self, $host) = @_;
  return store->exists( $self->{path} . "/host/$host" );
}

sub hosts
{
  my ($self) = @_;
  if (!exists $self->{_hostlist})
  {
    $self->{_hostlist} = [ map { $self->host($_) } store->get_children( $self->{path} . '/host' ) ];
  }
  return @{ $self->{_hostlist} };
}

sub hosts_in_slot
{
  my ($self, $slot) = @_;
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
  my ($self, $slot) = @_;
  return grep { !$_->is_finished } $self->hosts_in_slot($slot);
}

sub unsuccessful_hosts_in_slot
{
  my ($self, $slot) = @_;
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
  my $state = $self->state;
  return $state eq 'running'
    or $state eq 'gathering';
}

sub is_slot_done
{
  my ($self, $slot) = @_;
  return scalar $self->unfinished_hosts_in_slot($slot) == 0;
}

sub is_slot_successful
{
  my ($self, $slot) = @_;
  return scalar $self->unsuccessful_hosts_in_slot($slot) == 0;
}

sub runnable_hostinfo
{
  my ($self) = @_;
  my @runnable = $self->runnable_hosts;
  return { map { $_->name, $_->info } @runnable };
}

# odd, why is this here?
sub _get_pwent
{
  my ($self) = @_;
  my $entry = Pogo::Dispatcher->instance->pwstore->get( $self->{id} );
  LOGDIE "No password entry found for job $self->{id}!" if ( !$entry );
  return $entry;
}

# ugh this bugs me
sub encode_perl
{
  local $Data::Dumper::Terse = 1;
  local $Data::Dumper::Indent = 0;
  local $Data::Dumper::Purity = 1;
  local $Data::Dumper::Useqq = 1;
  return Dumper(@_);
}

sub password { return $_[0]->_get_pwent()->[0]; }
sub pkg_passwords { return $_[0]->_get_pwent()->[1]; }
sub namespace   { return $_[0]->{ns} }
sub id          { return $_[0]->{id} }
sub user        { return $_[0]->meta('user'); }
sub run_as      { return $_[0]->meta('run_as'); }
sub timeout     { return $_[0]->meta('timeout'); }
sub job_timeout { return $_[0]->meta('job_timeout'); }
sub retry       { return $_[0]->meta('retry'); }
sub command     { return $_[0]->meta('command'); }
sub concurrent  { return $_[0]->meta('concurrent'); }
sub state { return store->get( $_[0]->{path} ); }

sub set_state
{
  my ($self, $state, $msg, @extra) = @_;
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

# wow this is awkward
sub worker_command
{
  my ($self) = @_;
  my %meta = $self->all_meta;
  my $exe = delete $meta{exe_data} || '';
  my $worker_stub = read_file( Pogo::Dispatcher->instance()->worker_script() ) . encode_perl(
    {
      job => $self->id,
      api => Pogo::Server->instance()->{api_uri},
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

# {{{ actions

sub start
{
  my ($self, $errc, $cont) = @_;

  # do hostinfo lookup for the targets
  my $target = from_json( $self->meta('target') );
  my $ns = $self->namespace;
  my $concurrent = $self->concurrent;

  $self->set_state('gathering', 'job created; fetching hostinfo', target => $target );
  INFO "starting job " . $self->id;

  my $fetching_error = sub {
    ERROR $self->id . ": unable to obtain hostinfo for target: $@";
    $self->set_state('halted', "unable to obtain hostinfo for target: $@");
    return $errc->();
  };

  Pogo::Engine::fetch_hostinfo(
    $target,
    $ns->name,
    $fetching_error,
    sub {
    },
    );
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
