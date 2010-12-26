package PogoTester;

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

use Time::HiRes qw(sleep);
use Log::Log4perl qw(:easy);

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket qw(tcp_connect);
use AnyEvent::TLS;
use JSON::XS ();
use YAML::XS qw(LoadFile);
use Net::SSLeay;
use Data::Dumper;
use Carp qw(croak confess);
use Exporter 'import';
use FindBin qw($Bin);
use Template;
use LWP;

use lib "$Bin/../lib";
use lib "$Bin/../../lib";

use Pogo::Engine;
use Pogo::Engine::Store;

our @EXPORT = qw(test_pogo derp dispatcher_rpc worker_rpc authstore_rpc);

Log::Log4perl::init("$Bin/conf/log4perl.conf");

my $bind_address = '127.0.0.1';
my $dispatcher_conf;
my $worker_conf;
my $zookeeper_pid;
my $dispatcher_pid;
my $worker_pid;

sub test_pogo(&)
{
  my $cb = shift;

  chdir($Bin);
  system("rm -rf $Bin/.tmp");
  mkdir "$Bin/.tmp"
    unless -d "$Bin/.tmp";
  mkdir "$Bin/.tmp/pogo_output"
    unless -d "$Bin/.tmp/pogo_output";

  $dispatcher_conf = LoadFile("$Bin/conf/dispatcher.conf");
  $worker_conf     = LoadFile("$Bin/conf/worker.conf");

  start_zookeeper();
  sleep 2.5;
  init_store();
  start_dispatcher();

  sleep 2.5;
  start_worker();
  $cb->();
}

sub start_dispatcher
{
  return if $dispatcher_pid;
  $dispatcher_pid = fork();

  if ( $dispatcher_pid == 0 )
  {
    open STDOUT, "|tee $Bin/.tmp/dispatcher.log";
    open STDERR, '>&STDOUT';
    close STDIN;
    exec(
      "/usr/bin/env",                "perl", "-I$Bin/../lib", "-I$Bin/lib",
      "$Bin/../bin/pogo-dispatcher", '-f',   "$Bin/conf/dispatcher.conf"
    ) or LOGDIE $!;
  }
  else
  {
    INFO "spawned dispatcher (pid $dispatcher_pid)";
    open my $pidfile, '>', "$Bin/.tmp/dispatcher.pid";
    print $pidfile $dispatcher_pid;
    close $pidfile;
  }
}

sub stop_dispatcher
{
  if ( !defined $dispatcher_pid && -r "$Bin/.tmp/dispatcher.pid" )
  {
    open my $pidfile, '<', "$Bin/.tmp/dispatcher.pid";
    $dispatcher_pid = <$pidfile>;
    close $pidfile;
    unlink "$Bin/.tmp/dispatcher.pid";
  }

  return unless $dispatcher_pid;
  INFO "killing $dispatcher_pid";
  kill( TERM => $dispatcher_pid );
  undef $dispatcher_pid;
}

sub start_zookeeper
{
  return if $zookeeper_pid;
  my $zookeeper_cmd =
    `$Bin/../build/zookeeper/bin/zkServer.sh print-cmd $Bin/conf/zookeeper.conf 2>/dev/null`;
  DEBUG "using '$zookeeper_cmd'";

  $zookeeper_pid = fork();

  if ( $zookeeper_pid == 0 )
  {
    open STDOUT, "|tee $Bin/.tmp/zookeeper.log";
    open STDERR, '>&STDOUT';
    close STDIN;
    exec($zookeeper_cmd) or LOGDIE "$zookeeper_cmd failed: $!";
  }
  else
  {
    INFO "spawned zookeeper (pid $zookeeper_pid)";
    open my $pidfile, '>', "$Bin/.tmp/zookeeper.pid";
    print $pidfile $zookeeper_pid;
    close $pidfile;
  }
}

sub stop_zookeeper
{
  if ( !defined $zookeeper_pid && -r "$Bin/.tmp/zookeeper.pid" )
  {
    open my $pidfile, '<', "$Bin/.tmp/zookeeper.pid";
    $zookeeper_pid = <$pidfile>;
    close $pidfile;
    unlink "$Bin/.tmp/zookeeper.pid";
  }

  return unless $zookeeper_pid;
  INFO "killing $zookeeper_pid";
  kill( TERM => $zookeeper_pid );
  undef $zookeeper_pid;
}

sub start_worker
{
  return if $worker_pid;
  $worker_pid = fork();

  if ( $worker_pid == 0 )
  {
    open STDOUT, "|tee $Bin/.tmp/worker.log";
    open STDERR, '>&STDOUT';
    close STDIN;
    exec(
      "/usr/bin/env",            "perl", "-I$Bin/../lib", "-I$Bin/lib",
      "$Bin/../bin/pogo-worker", '-f',   "$Bin/conf/worker.conf"
    ) or LOGDIE $!;
  }
  else
  {
    INFO "spawned worker (pid $worker_pid)";
    open my $pidfile, '>', "$Bin/.tmp/worker.pid";
    print $pidfile $worker_pid;
    close $pidfile;
  }
}

sub stop_worker
{
  if ( !defined $worker_pid && -r "$Bin/.tmp/worker.pid" )
  {
    open my $pidfile, '<', "$Bin/.tmp/worker.pid";
    $worker_pid = <$pidfile>;
    close $pidfile;
    unlink "$Bin/.tmp/worker.pid";
  }

  return unless $worker_pid;
  INFO "killing $worker_pid";
  kill( TERM => $worker_pid );
  undef $worker_pid;
}

sub init_store
{
  Pogo::Engine::Store->init($dispatcher_conf);
}

# send raw json-rpc back and forth to our authstore port
sub authstore_rpc
{
  my ( $self, $rpc ) = @_;
  my $cv = AnyEvent->condvar;
  if ( !defined $self->{authstore_handle} )
  {
    DEBUG "creating new authstore handle";
    tcp_connect(
      $self->{bind_address},
      $self->{authstore_port},
      sub {
        my ( $fh, $host, $port ) = @_;
        if ( !$host && !$port )
        {
          ERROR "connection failed: $!";
          return;
        }
        DEBUG "connection successful, starting SSL negotiation";
        $self->{authstore_handle} = AnyEvent::Handle->new(
          fh       => $fh,
          tls      => 'connect',
          tls_ctx  => $self->{authstore_ctx},
          no_delay => 1,
          on_eof   => sub {
            delete $self->{authstore_handle};
            INFO "connection closed to $host:$port";
          },
          on_error => sub {
            delete $self->{authstore_handle};
            my $fatal = $_[1];
            LOGDIE
              sprintf( "$host:$port reported %s error: %s", $fatal ? 'fatal' : 'non-fatal', $! );
          },
        ) || LOGDIE "couldn't create handle: $!";
        $self->{authstore_handle}->push_write( json => $rpc );
        $self->{authstore_handle}->push_read( json => sub { $cv->send( $_[1] ); }, );
      },
    );
  }
  else
  {
    $self->{authstore_handle}->push_write( json => $rpc );
    $self->{authstore_handle}->push_read( json => sub { $cv->send( $_[1] ); }, );
  }

  return $cv->recv;
}

sub dispatcher_rpc
{
  my $rpc = shift;
  my $url = sprintf( 'http://%s:%d/v3', $bind_address, $dispatcher_conf->{http_port} );
  my $res = LWP::UserAgent->new->post( $url, { 'r' => JSON::XS::encode_json($rpc) } );
  return JSON::XS::decode_json( $res->decoded_content );
}

sub worker_rpc
{
  my $rpc = shift;
  my $cv  = AnyEvent->condvar;
  my $handle;
  $handle = AnyEvent::Handle->new(
    connect => [ $bind_address, $dispatcher_conf->{worker_port} ],
    tls     => 'connect',
    tls_ctx => {
      key_file  => "$Bin/conf/worker.key",
      cert_file => "$Bin/conf/worker.cert",
      ca_file   => "$Bin/conf/dispatcher.cert",
      verify    => 1,
      verify_cb => sub {
        my $preverify_ok = $_[4];
        my $cert         = $_[6];
        DEBUG sprintf( "certificate: %s", AnyEvent::TLS::certname($cert) );
        return $preverify_ok;
      },
    },
    no_delay => 1,
    on_error => sub {
      $handle->destroy;
      my $fatal = $_[1];
      LOGDIE sprintf(
        "%s:%d reported %s error: %s",
        $bind_address,
        $dispatcher_conf->{worker_port},
        $fatal ? 'fatal' : 'non-fatal', $!
      );
    },
  );
  $handle->push_write( json => $rpc );
  $handle->push_read( json => sub { $cv->send( $_[1] ); } );

  return $cv->recv;
}

# pretty-print a test failure
sub derp
{
  my ( $test, $obj ) = @_;
  my $dump = Data::Dumper::Dumper($obj);
  my $str  = <<"__DERP__";
Test name: $test
Result: $dump
__DERP__

  return $str;
}

END
{
  if ( defined $ENV{POGO_PERSIST} )
  {
    INFO "persisting started services";
    return;
  }
  stop_worker();
  stop_dispatcher();
  stop_zookeeper();
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
