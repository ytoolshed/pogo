package Pogo::API::V3;

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

use Log::Log4perl qw(:easy);
use JSON qw(to_json);
use Sys::Hostname qw(hostname);
use YAML::XS qw(LoadFile);

use Pogo::Common;
use Pogo::Engine;
use Pogo::Engine::Job;
use Pogo::Engine::Response;

our $instance;

sub init
{
  my $class = shift;
  my $self = { hostname => hostname(), };
  DEBUG "new instance [$$]";
  my $conf;
  eval { $conf = LoadFile( $Pogo::Common::CONFIGDIR . '/dispatcher.conf' ); };
  Pogo::Engine->init($conf);
  return bless $self, $class;
}

sub instance
{
  my ( $class, %opts ) = @_;
  $instance ||= $class->init(%opts);
  return $instance;
}

# all rpc methods return an Engine::Response object
sub _rpc_ping      { my $self = shift; return Pogo::Engine->ping(@_); }
sub _rpc_stats     { my $self = shift; return Pogo::Engine->stats(@_); }
sub _rpc_listjobs  { my $self = shift; return Pogo::Engine->listjobs(@_); }
sub _rpc_jobinfo   { my $self = shift; return Pogo::Engine->jobinfo(@_); }
sub _rpc_jobstatus { my $self = shift; return Pogo::Engine->jobstatus(@_); }
sub _rpc_joblog    { my $self = shift; return Pogo::Engine->joblog(@_); }

sub _rpc_run
{
  my ( $self, %args ) = @_;

  my $resp = Pogo::Engine::Response->new()->add_header( action => 'run' );

  foreach my $arg (qw(user run_as command target password namespace))
  {
    if ( !exists $args{$arg} )
    {
      $resp->set_error("Mandatory argument '$arg' missing from 'run' request");
      DEBUG "failed run, got args " . join( ",", keys(%args) );
      return $resp;
    }
  }
  my $run_as  = $args{run_as};
  my $command = $args{command};
  my $target  = $args{target};

  $args{timeout}     ||= 600;
  $args{job_timeout} ||= 1800;
  $args{retry}       ||= 0;

  # why are we encoding this twice? dumb
  # $args{pkg_passwords} = to_json( $args{pkg_passwords} );

  my $opts = {};
  foreach my $arg (
    qw(invoked_as namespace target user run_as password timeout job_timeout
    command retry prehook posthook pkg_passwords email im_handle client
    requesthost concurrent exe_name exe_data)
    )
  {
    $opts->{$arg} = $args{$arg} if exists $args{$arg};
  }
  my $job = Pogo::Engine::Job->new($opts);
  $resp->set_ok;
  DEBUG $job->id . ": running $command as $run_as on: " . to_json($target);
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

  Andrew Sloane <asloane@yahoo-inc.com>
  Michael Fischer <mfischer@yahoo-inc.com>
  Nicholas Harteau <nrh@yahoo-inc.com>
  Nick Purvis <nep@yahoo-inc.com>
  Robert Phan <rphan@yahoo-inc.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
