package Pogo::API::V3;

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

use Carp ();
use Log::Log4perl qw(:easy);
use JSON qw(encode_json);
use Sys::Hostname qw(hostname);
use YAML::XS qw(LoadFile);

use Pogo::Common;
use Pogo::Engine;
use Pogo::Engine::Job;
use Pogo::Engine::Response;

my %METHODS = (
  err           => 'err',
  globalstatus  => 'globalstatus',
  hostinfo      => 'hostinfo',
  hostlog_url   => 'hostlog_url',
  jobalter      => 'jobalter',
  jobhalt       => 'jobhalt',
  jobhoststatus => 'jobhoststatus',
  jobinfo       => 'jobinfo',
  joblog        => 'joblog',
  jobresume     => 'jobresume',
  jobretry      => 'jobretry',
  jobskip       => 'jobskip',
  jobsnapshot   => 'jobsnapshot',
  jobstatus     => 'jobstatus',
  lastjob       => 'lastjob',
  listjobs      => 'listjobs',
  loadconf      => 'loadconf',
  ping          => 'ping',
  run           => 'run',
  stats         => 'stats',
  storesecrets  => 'storesecrets',
  add_task      => 'add_task',
);

sub AUTOLOAD
{
  use vars '$AUTOLOAD';
  DEBUG "in autoload for $AUTOLOAD";
  my ($methodname) = ( $AUTOLOAD =~ m/(\w+)$/ );
  if ( my $method = $METHODS{$methodname} )
  {
    shift @_;    # throw out classname
    return Pogo::Engine->$method(@_);
  }
  else
  {
    my $response = Pogo::Engine::Response->new;
    $response->set_error("unknown rpc command '$methodname'");
    return $response;
  }
}

# Explicitly declare DESTROY method so it's not autoloaded
sub DESTROY
{
}

# all rpc methods return an Engine::Response object
sub _rpc_ping        { my $self = shift; return Pogo::Engine->ping(@_); }
sub _rpc_stats       { my $self = shift; return Pogo::Engine->stats(@_); }
sub _rpc_listjobs    { my $self = shift; return Pogo::Engine->listjobs(@_); }
sub _rpc_jobinfo     { my $self = shift; return Pogo::Engine->jobinfo(@_); }
sub _rpc_jobstatus   { my $self = shift; return Pogo::Engine->jobstatus(@_); }
sub _rpc_jobsnapshot { my $self = shift; return Pogo::Engine->jobsnapshot(@_); }
sub _rpc_joblog      { my $self = shift; return Pogo::Engine->joblog(@_); }

sub ping        { shift; return Pogo::Engine->ping(@_); }
sub stats       { shift; return Pogo::Engine->stats(@_); }
sub listjobs    { shift; return Pogo::Engine->listjobs(@_); }
sub jobinfo     { shift; return Pogo::Engine->jobinfo(@_); }
sub jobstatus   { shift; return Pogo::Engine->jobstatus(@_); }
sub jobsnapshot { shift; return Pogo::Engine->jobsnapshot(@_); }
sub joblog      { shift; return Pogo::Engine->joblog(@_); }

sub run { _rpc_run(@_) }

sub _rpc_run
{
  my ( $self, %args ) = @_;

  my $resp = Pogo::Engine::Response->new()->add_header( action => 'run' );

  foreach my $arg (qw(user run_as command target namespace))
  {
    if ( !exists $args{$arg} )
    {
      $resp->set_error("Mandatory argument '$arg' missing from 'run' request");
      DEBUG "failed run, got args " . join( ",", keys(%args) );
      return $resp;
    }
  }

  unless ( exists $args{'password'} || exists $args{'client_private_key'} )
  {
    $resp->set_error( "Either password or passphrase and client_private_key combination "
        . "needs to be provided with 'run' request" );
    DEBUG "failed run, password or passphrase and private key not provided";
    return $resp;
  }

  my $run_as  = $args{run_as};
  my $command = $args{command};
  my $target  = $args{target};

  $args{timeout}     ||= 600;
  $args{job_timeout} ||= 1800;
  $args{retry}       ||= 0;

  my $opts = {};
  foreach my $arg (
    qw(invoked_as namespace target user run_as password pvt_key_passphrase
    client_private_key timeout job_timeout command retry prehook posthook
    secrets email root_type im_handle client requesthost concurrent exe_name
    exe_data signature_fields signature)
    )
  {
    $opts->{$arg} = $args{$arg} if exists $args{$arg};
  }
  my $job = Pogo::Engine::Job->new($opts);
  $resp->set_ok;
  DEBUG $job->id . ": running '$command' as $run_as on: " . encode_json($target);
  $resp->add_record( $job->id );
  return $resp;
}

# this is the main entry point for V3.pm
# /pogo?r=[1,2,3] => rpc(1,2,3)
sub rpc
{
  my ( $self, $action, @args ) = @_;
  my $response = Pogo::Engine::Response->new();

  my $method = '_rpc_' . $action;

  $response->add_header( action => $action );
  my $out = $self->$method(@args);
  return $out
    if ref $out eq 'Pogo::Engine::Response';

  if ($@)
  {
    ERROR "$method: $@";
    $response->set_error($@);
  }
  else
  {
    WARN "$method returned a non-response object?";
    $response->set_ok;
    $response->set_records($out);
  }

  return $response;
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

  Andrew Sloane <andy@a1k0n.net>
  Ian Bettinger <ibettinger@yahoo.com>
  Michael Fischer <michael+pogo@dynamine.net>
  Mike Schilli <m@perlmeister.com>
  Nicholas Harteau <nrh@hep.cat>
  Nick Purvis <nep@noisetu.be>
  Robert Phan <robert.phan@gmail.com>
  Srini Singanallur <ssingan@yahoo.com>
  Yogesh Natarajan <yogesh_ny@yahoo.co.in>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
