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

use strict;
use warnings;

use Time::HiRes qw(sleep);
use Log::Log4perl qw(:easy);

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket qw(tcp_connect);
use AnyEvent::TLS;
use YAML::XS qw(LoadFile);
use Net::SSLeay;
use JSON qw(to_json from_json);
use Data::Dumper;
use Carp qw(croak confess);

use FindBin qw($Bin);

our $dispatcher_pid;
our $zookeeper_pid;
our $cv = AnyEvent->condvar;

sub new
{
  my ( $class, %opts ) = @_;
  mkdir "$Bin/.tmp"
    unless -d "$Bin/.tmp";

  my $conf = $opts{conf} || "$Bin/conf/dispatcher.conf";
  my $self = LoadFile($conf);

  $self->{worker_ctx} = AnyEvent::TLS->new(
    key_file                   => "$Bin/conf/worker.key",
    cert_file                  => "$Bin/conf/worker.cert",
    verify_require_client_cert => 1,
    verify                     => 0,
  ) || LOGDIE "Couldn't init: $!";
  $self->{authstore_ctx} = AnyEvent::TLS->new(
    key_file                   => "$Bin/conf/authstore.key",
    cert_file                  => "$Bin/conf/authstore.cert",
    verify_require_client_cert => 1,
    verify                     => 0,
  ) || LOGDIE "Couldn't init: $!";
  $self->{dispatcher_ctx} = AnyEvent::TLS->new(
    key_file                   => "$Bin/conf/dispatcher.key",
    cert_file                  => "$Bin/conf/dispatcher.cert",
    verify_require_client_cert => 1,
    verify                     => 0,
  ) || LOGDIE "Couldn't init: $!";

  return bless $self, $class;
}

sub start_dispatcher
{
  my ( $self, %opts ) = @_;
  my $conf = $opts{conf} || "$Bin/conf/dispatcher.conf";
  $dispatcher_pid = fork();

  if ( $dispatcher_pid == 0 )
  {
    exec( "/usr/local/bin/perl", "-I$Bin/../lib", "-I$Bin/lib", "$Bin/../bin/pogo-dispatcher", '-f',
      $conf )
      or LOGDIE $!;
  }
  else
  {
    sleep(2.5);
    INFO "spawned dispatcher (pid $dispatcher_pid)";
  }

  return 1;
}

sub stop_dispatcher
{
  my $self = shift;
  sleep(0.2);
  INFO "killing $dispatcher_pid";
  kill( 15, $dispatcher_pid );
  return 1;
}

sub start_zookeeper
{
  my ( $self, %opts ) = @_;
  my $conf = $opts{zookeeper_conf} || "$Bin/conf/zookeeper.conf";
  $zookeeper_pid = fork();

  my $zookeeper_cmd = `zookeeper-server.sh print-cmd $conf 2>/dev/null`;
  if ( $zookeeper_pid == 0 )
  {
    exec($zookeeper_cmd )
      or LOGDIE $!;
  }
  else
  {
    sleep(2.5);
    INFO "spawned zookeeper (pid $zookeeper_pid)";
  }

  return 1;
}

sub stop_zookeeper
{
  my $self = shift;
  sleep(0.2);
  INFO "killing $zookeeper_pid";
  kill( 15, $zookeeper_pid );
  return 1;
}

# send raw json-rpc back and forth to our authstore port
sub authstore_rpc
{
  my ( $self, $rpc ) = @_;
  if ( !defined $self->{authstore_handle} )
  {
    DEBUG "creating new authstore handle";
    tcp_connect(
      '127.0.0.1',
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
            LOGDIE sprintf( "$host:$port reported %s error: %s",
               $fatal ? 'fatal' : 'non-fatal', $! );
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
  my ( $self, $rpc ) = @_;
  if ( !defined $self->{dispatcher_handle} )
  {
    DEBUG "creating new dispatcher handle";
    tcp_connect(
      '127.0.0.1',
      $self->{rpc_port},
      sub {
        my ( $fh, $host, $port ) = @_;
        if ( !$host && !$port )
        {
          ERROR "connection failed: $!";
          return;
        }
        DEBUG "connection successful, starting SSL negotiation";
        $self->{dispatcher_handle} = AnyEvent::Handle->new(
          fh       => $fh,
          tls      => 'connect',
          tls_ctx  => $self->{dispatcher_ctx},
          no_delay => 1,
          on_eof   => sub {
            delete $self->{dispatcher_handle};
            INFO "connection closed to $host:$port";
          },
          on_error => sub {
            delete $self->{dispatcher_handle};
            my $fatal = $_[1];
            LOGDIE sprintf( "$host:$port reported %s error: %s",
               $fatal ? 'fatal' : 'non-fatal', $! );
          },
        ) || LOGDIE "couldn't create handle: $!";
        $self->{dispatcher_handle}->push_write( json => $rpc );
        $self->{dispatcher_handle}->push_read( json => sub { $cv->send( $_[1] ); }, );
      },
    );
  }
  else
  {
    $self->{dispatcher_handle}->push_write( json => $rpc );
    $self->{dispatcher_handle}->push_read( json => sub { $cv->send( $_[1] ); }, );
  }

  return $cv->recv;
}

sub worker_rpc
{
  my ( $self, $rpc ) = @_;
  if ( !defined $self->{worker_handle} )
  {
    DEBUG "creating new worker handle";
    tcp_connect(
      '127.0.0.1',
      $self->{worker_port},
      sub {
        my ( $fh, $host, $port ) = @_;
        if ( !$host && !$port )
        {
          ERROR "connection failed: $!";
          return;
        }
        DEBUG "connection successful, starting SSL negotiation";
        $self->{worker_handle} = AnyEvent::Handle->new(
          fh       => $fh,
          tls      => 'connect',
          tls_ctx  => $self->{worker_ctx},
          no_delay => 1,
          on_eof   => sub {
            delete $self->{worker_handle};
            INFO "connection closed to $host:$port";
          },
          on_error => sub {
            delete $self->{worker_handle};
            my $fatal = $_[1];
            LOGDIE sprintf( "$host:$port reported %s error: %s",
               $fatal ? 'fatal' : 'non-fatal', $! );
          },
        ) || LOGDIE "couldn't create handle: $!";
        $self->{worker_handle}->push_write( json => $rpc );
        $self->{worker_handle}->push_read( json => sub { $cv->send( $_[1] ); }, );
      },
    );
  }
  else
  {
    $self->{worker_handle}->push_write( json => $rpc );
    $self->{worker_handle}->push_read( json => sub { $cv->send( $_[1] ); }, );
  }

  return $cv->recv;
}

sub bin
{
  print $Bin;
}

1;

