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
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::TLS;

use FindBin qw($Bin);

our $dispatcher_pid;
our $zookeeper_pid;

sub new
{
  my ($class, $opts) = @_;

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
      or die $!;
  }

  # wait for server startup
  sleep(3.5);
  return 1;
}

sub stop_dispatcher
{
  sleep(0.2);
  kill( 15, $dispatcher_pid );
  return 1;
}

sub start_zookeeper
{
  $ENV{ZOOPIDFILE} = "$Bin/zookeeper.pid";
  $ENV{CLASSPATH} = "


  return 1;
}

sub stop_zookeeper
{
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

