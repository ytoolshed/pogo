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
use AnyEvent::Socket;
use AnyEvent::TLS;

use FindBin qw($Bin);

our $dispatcher_pid;
our $zookeeper_pid;

sub new
{
  my ( $class, $opts ) = @_;

  my $self = {};
  $self->{worker_ctx} = AnyEvent::TLS->new(
      key_file                   => "$Bin/conf/worker.key",
      cert_file                  => "$Bin/conf/worker.cert",
      verify_require_client_cert => 1,
      verify                     => 1,
    ) || LOGDIE "Couldn't init: $!";
  $self->{authstore_ctx} = AnyEvent::TLS->new(
      key_file                   => "$Bin/conf/authstore.key",
      cert_file                  => "$Bin/conf/authstore.cert",
      verify_require_client_cert => 1,
      verify                     => 1,
    ) || LOGDIE "Couldn't init: $!";
  $self->{dispatcher_ctx} = AnyEvent::TLS->new(
      key_file                   => "$Bin/conf/dispatcher.key",
      cert_file                  => "$Bin/conf/dispatcher.cert",
      verify_require_client_cert => 1,
      verify                     => 1,
    ) || LOGDIE "Couldn't init: $!";

  return bless $self, $class;
}

sub start_dispatcher
{
  my (%opts) = @_;
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
    sleep(3.5);
    INFO "spawned dispatcher (pid $dispatcher_pid)";
  }

  return 1;
}

sub stop_dispatcher
{
  sleep(0.2);
  INFO "killing $dispatcher_pid";
  kill( 15, $dispatcher_pid );
  return 1;
}

sub start_zookeeper
{
  my (%opts) = @_;
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
    sleep(3.5);
    INFO "spawned zookeeper (pid $zookeeper_pid)";
  }

  return 1;
}

sub stop_zookeeper
{
  sleep(0.2);
  INFO "killing $zookeeper_pid";
  kill( 15, $zookeeper_pid );
  return 1;
}

# send raw json-rpc back and forth to our authstore port
sub authstore_rpc
{
  my $self = shift;
}

sub dispatcher_rpc
{
  my $self = shift;
}

sub worker_rpc
{
  my $self = shift;
}

sub bin
{
  print $Bin;
}

1;

