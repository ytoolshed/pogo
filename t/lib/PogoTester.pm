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

use FindBin qw($Bin);

our $serverpid;

sub start_dispatcher
{
  my (%opts) = @_;
  my $conf = $opts{conf} || "$Bin/conf/dispatcher.conf";
  $serverpid = fork();

  if ( $serverpid == 0 )
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
  kill( 15, $serverpid );
  return 1;
}

sub start_zookeeper
{
  return 1;
}

sub bin
{
  print $Bin;
}

1;

