package Pogo::Engine;

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

use strict;
use warnings;

use AnyEvent;
use Log::Log4perl qw(:easy);
use JSON qw(from_json);
use YAML::XS qw(LoadFile);
use Data::Dumper qw(Dumper);

use Pogo::Engine::Job;
use Pogo::Engine::Namespace;
use Pogo::Engine::Store;
use Pogo::Roles;

our $instance;
our $nscache;

sub instance
{
  return $instance
    if defined $instance;

  my ( $class, $opts ) = @_;
  DEBUG "new Pogo::Engine instance";

  $instance = {
    client_min => $opts->{client_min} || '0.0.0',
    start_time => time(),
  };

  $instance->{store} = Pogo::Engine::Store->new($opts);

  return bless $instance, $class;
}

# init is called from the API handler and we need to load the config that
# we'd normally load in pogo-dispatcher
sub init
{
  my ( $class, $conf ) = @_;

  LOGDIE "no configuration?" unless $conf->{worker_cert};  # arbitrary canary

  return $class->instance($conf);
}

sub store
{
  LOGDIE "not yet initialized" unless defined $instance;
  return $instance->{store};
}

# convenience interfaces into Engine sublcasses

sub namespace
{
  my ( $class, $nsname ) = @_;
  $nscache->{$nsname} ||= Pogo::Engine::Namespace->new($nsname);
  return $nscache->{$nsname};
}

sub job
{
  my ( $class, $jobid ) = @_;
  return Pogo::Engine::Job->get($jobid);
}

# these should be available via the http api and the json-rpc connection handler

# this seems to be unused currently
#sub err
#{
#  return LOGDIE "@_";
#}

sub globalstatus
{
  my ( $ns, @args ) = @_;
  my $resp = new Pogo::Engine::Respone;
  $resp->add_header( action => 'globalstatus' );

  $resp->set_records( $instance->namespace($ns)->global_get_locks(@args) );
  $resp->set_ok;

  return $resp;
}

sub hostinfo
{
  my $range = shift;
  my $ns    = shift;

  my $resp = new Pogo::Engine::Response;
  $resp->add_header( action => 'hostinfo' );

  my $error;
  my $w = AnyEvent->condvar;

  # call this asyncronously as it may be ugly
  Pogo::Roles->instance->fetch_all(
    $range, $ns,
    sub {
      $resp->set_error(shift);
      $w->send;
    },
    sub {
      my ( $results, $hosts ) = @_;
      $resp->add_header( hosts => join( ',', @$hosts ) );
      $resp->set_ok;
      $resp->set_records($results);
      $w->send;
    },
  );

  $w->recv;

  return $resp;
}

sub hostlog_url
{
  my ( $jobid, @hostnames ) = @_;
  my $job  = $instance->job($jobid);
  my $resp = new Pogo::Engine::Response;
  $resp->add_header( action => 'hostlog_url' );

  if ( !defined $job )
  {
    $resp->set_error("jobid $jobid not found");
    return $resp;
  }

  $resp->set_ok;

  foreach my $host (@hostnames)
  {
    my $urls = $job->host($host)->outputurl;
    $resp->add_record( [ $host, @$urls ] );
  }

  $resp->add_header( hosts => join ',', @hostnames );

  return $resp;
}

sub jobalter
{
  my ( $jobid, %alter ) = @_;
  my $job  = $instance->job($jobid);
  my $resp = new Pogo::Engine::Response;
  $resp->add_header( action => 'jobalter' );

  if ( !defined $job )
  {
    $resp->set_error("jobid $jobid not found");
    return $resp;
  }

  while ( my ( $k, $v ) = each %alter )
  {
    if ( !$job->set_meta( $k, $v ) )
    {
      $resp->set_error("failed to set $k=$v for $jobid");
      return $resp;
    }
  }
  $resp->set_ok;

  return $resp;
}

sub jobhalt
{
  my $jobid = shift;
  my $job   = $instance->job($jobid);
  my $resp  = new Pogo::Engine::Response;
  $resp->add_header( action => 'jobhalt' );

  if ( !defined $job )
  {
    $resp->set_error("jobid $jobid not found");
    return $resp;
  }

  if ( !$job->halt )
  {
    $resp->set_error("error halting $jobid");
    return $resp;
  }

  $resp->set_ok;
  return $resp;
}

sub jobhoststatus
{
  my ( $jobid, $hostname ) = @_;
  my $job  = $instance->job($jobid);
  my $resp = new Pogo::Engine::Response;

  $resp->add_header( action => 'jobhoststatus' );

  if ( !defined $job )
  {
    $resp->set_error("jobid $jobid not found");
    return $resp;
  }

  if ( !job->has_host($hostname) )
  {
    $resp->set_error("host $hostname not part of job $jobid");
    return $resp;
  }

  $resp->set_records( $job->host($hostname)->state );
  $resp->set_ok;
  return $resp;
}

sub jobinfo
{
  my $jobid = shift;
  my $job   = $instance->job($jobid);
  my $resp  = new Pogo::Engine::Response;

  $resp->add_header( action => 'jobinfo' );

  if ( !defined $job )
  {
    $resp->set_error("jobid $jobid not found");
    return $resp;
  }

  $resp->set_records( $job->info );
  $resp->set_ok;

  return $resp;
}

sub joblog
{
  my ( $jobid, $offset, $limit ) = @_;
  my $job  = $instance->job($jobid);
  my $resp = new Pogo::Engine::Response;

  $resp->add_header( action => 'joblog' );

  if ( !defined $job )
  {
    $resp->set_error("jobid $jobid not found");
    return $resp;
  }

  $resp->set_records( $job->read_log( $offset, $limit ) );
  $resp->set_ok;

  return $resp;
}

sub jobresume
{
  my $jobid = shift;
  my $job   = $instance->job($jobid);
  my $resp  = new Pogo::Engine::Response;

  $resp->add_header( action => 'jobresume' );

  if ( !defined $job )
  {
    $resp->set_error("jobid $jobid not found");
    return $resp;
  }

  if ( $job->state ne 'halted' )
  {
    $resp->set_error("job $jobid not halted; cannot resume");
    return $resp;
  }

  $instance->add_task( 'resumejob', $job->{id} );
  $resp->set_ok;

  return $resp;
}

sub jobretry
{
  my ( $jobid, @hostnames ) = @_;
  my $job  = $instance->job($jobid);
  my $resp = new Pogo::Engine::Response;

  $resp->add_header( action => 'jobretry' );

  if ( !defined $job )
  {
    $resp->set_error("jobid $jobid not found");
    return $resp;
  }

  my $out = [ map { $job->retry_host($_) } @hostnames ];
  $instance->add_task( 'resumejob', $job->{id} );

  $resp->set_records($out);
  $resp->set_ok;

  return $resp;
}

sub jobskip
{
  my ( $jobid, @hostnames ) = @_;
  my $job  = $instance->job($jobid);
  my $resp = new Pogo::Engine::Response;

  $resp->add_header( action => 'jobskip' );

  if ( !defined $job )
  {
    $resp->set_error("jobid $jobid not found");
    return $resp;
  }

  my $out = [ map { $job->skip_host($_) } @hostnames ];
  $instance->add_task( 'continuejob', $job->{id} );

  $resp->set_records($out);
  $resp->set_ok;

  return $resp;
}

sub jobsnapshot
{
  my ( $jobid, $offset ) = @_;
  my $job  = $instance->job($jobid);
  my $resp = new Pogo::Engine::Response;

  $resp->add_header( action => 'jobsnapshot' );

  if ( !defined $job )
  {
    $resp->set_error("jobid $jobid not found");
    return $resp;
  }

  my ( $idx, $snap ) = $job->snapshot($offset);

  # $snap is a JSON-encoded string; we want to return it as a raw
  # value rather than re-encoding it in the Response object
  # i guess this means it'll have to be double-decoded in the client until we
  # can make Response.pm do what we want

  $resp->add_raw_record( [ $idx, $snap ] );
  $resp->set_ok;

  return $resp;
}

sub jobstatus
{
  my $jobid = shift;
  my $job   = $instance->job($jobid);
  my $resp  = new Pogo::Engine::Response;

  $resp->add_header( action => 'jobstatus' );

  if ( !defined $job )
  {
    $resp->set_error("jobid $jobid not found");
    return $resp;
  }

  my @hostlist = map { $resp->add_record( [ $_->name, $_->state ] ) } $job->hosts;
  $resp->add_header( hosts => join ',', @hostlist );
  $resp->set_ok;

  return $resp;
}

sub lastjob
{
  my (%matchopts) = @_;
  $matchopts{limit} = 1;
  my $resp = new Pogo::Engine::Response;
  $resp->set_header( action => 'lastjob' );

  my @jobs = $instance->_listjobs(%matchopts);
  $resp->set_ok;

  return $resp unless @jobs;

  $resp->add_record( pop(@jobs)->{jobid} );

  return $resp;
}

sub listjobs
{
  my (%matchopts) = @_;
  my $resp = new Pogo::Engine::Response;
  $resp->set_header( action => 'listjobs' );

  my @jobs = $instance->_listjobs( \%matchopts );
  $resp->set_ok;

  return $resp unless @jobs;

  $resp->set_records( \@jobs );

  return $resp;
}

sub _listjobs
{
  my ( $self, $matchopts ) = @_;

  my @jobs;

  my $limit  = delete $matchopts->{limit}  || 100;
  my $offset = delete $matchopts->{offset} || 0;
  my $jobidx = $instance->store->get_children_version("/pogo/job") - 1 - $offset;

JOB: for ( ; $jobidx >= 0 && $limit > 0; $jobidx-- )
  {
    my $jobid = sprintf( "p%010d", $jobidx );
    my $jobinfo = $self->job($jobid)->info;
    last unless defined $jobinfo;

    foreach my $k ( keys %$matchopts )
    {
      next JOB if ( !exists $jobinfo->{$k} );
      next JOB if ( $matchopts->{$k} ne $jobinfo->{$k} );
    }
    $jobinfo->{jobid} = $jobid;
    push @jobs, $jobinfo;
    $limit--;
  }
  return @jobs;
}

sub loadconf
{
  my ( $ns, $conf ) = @_;
  my $resp = new Pogo::Engine::Response;
  $resp->add_header( action => 'loadconf' );

  $instance->namespace($ns)->init->set_conf($conf);
}

sub ping
{
  my $pong = shift || 0xDEADBEEF;
  my $resp = new Pogo::Engine::Response;
  $resp->add_header( action => 'ping' );

  my $foo = $instance->store->ping($pong);
  if ( $foo eq $pong )
  {
    $resp->set_ok;
    $resp->add_record("PONG $foo");
    return $resp;
  }

  $resp->set_error($foo);
  return $resp;
}

sub _ping { return $instance->store->ping(@_); }

sub run
{
  my (%args) = @_;
  my $resp = new Pogo::Engine::Response;
  foreach my $arg (qw(user run_as command range password namespace pkg_passwords))
  {
    if ( !exists $args{$arg} )
    {
      $resp->set_error("missing '$arg'");
      return $resp;
    }
  }

  my $run_as  = $args{run_as};
  my $command = $args{command};
  my $range   = $args{range};

  $args{timeout}     ||= 600;
  $args{job_timeout} ||= 1800;
  $args{retry}       ||= 0;
  $args{pkg_passwords} = to_json( $args{pkg_passwords} );

  my $opts = {};
  foreach my $arg (
    qw(invoked_as namespace range user run_as password timeout job_timeout command retry prehook posthook pkg_passwords email im_handle client requesthost concurrent exe_name exe_data)
    )
  {
    $opts->{$arg} = $args{$arg} if exists $args{$arg};
  }

  my $job = Pogo::Engine::Job->new($opts);
  DEBUG $job->id . ": running $command as $run_as on " . to_json($range);

  $resp->add_record( "OK " . $job->id );
  $resp->set_ok;

  return $resp;
}

sub stats
{
  my @total_stats;
  foreach my $host ( $instance->store->get_children('/pogo/stats') )
  {
    my $path = '/pogo/stats/' . $host . '/current';
    if ( !$instance->store->exists($path) )
    {
      push( @total_stats, { hostname => $host, state => 'not connected' } );
      next;
    }

    my $raw_stats = $instance->store->get($path)
      or WARN "race condition? $path should exist but doesn't: " . $instance->store->get_error;

    my $host_stats;
    eval { $host_stats = from_json($raw_stats) };
    if ($@)
    {
      WARN "json decode of $path failed: $@";
      next;
    }
    push( @total_stats, $host_stats );
  }

  return \@total_stats;
}

sub add_task
{
  my ( $class, @task ) = @_;
  DEBUG "adding task: " . to_json( \@task );
  $instance->store->create( '/pogo/taskq' . join( ';', @task, '' ) )
    or LOGDIE $instance->store->get_error;
}

1;

=pod

=head1 NAME

  Pogo::Engine - interact with the pogo backend

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
