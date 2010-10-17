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

  return bless $class, $self;
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

  # wait for server startup
  sleep(3.5);
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

sub authstore_client
{
}

sub rpc_client
{
}

sub worker_client
{
}

sub bin
{
  print $Bin;
}

1;

