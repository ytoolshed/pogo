#!/usr/bin/env perl -w
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

use 5.008;
use common::sense;
#use strict;
#use warnings;

use Test::Exception;
use Test::More tests => 8;

use Carp qw(confess);
use Data::Dumper;
use FindBin qw($Bin);
use Log::Log4perl qw(:easy);

use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoMockGnuPG;
use Pogo::Client::GPGSignature qw(create_signature); 

*Pogo::Client::GPGSignature::get_password = \&main::mock_get_password;

sub mock_get_password
{
    return;
}

my %t;
my $job1 = {
    namespace => "batcave",
    target    => "gotham.needs.batman.com",
    timeout   => 0,
};

dies_ok { %t = create_signature($job1); } "No command or run_as present"
  or diag explain $@;

ok($@ =~ m/run_as and command are needed to sign a job/, 
   "run_as and command are needed to sign a job")
    or diag explain $@;

my $job2 = {
    command   => "echo batmobile",
    namespace => "batcave",
    target    => "gotham.needs.batman.com",
    timeout   => 0,
};

dies_ok { %t = create_signature($job2); } "run_as not present"
  or diag explain %t;
  
ok($@ =~ m/run_as and command are needed to sign a job/, 
   "run_as and command are needed to sign a job");

my $job3 = {
    namespace => "batcave",
    run_as    => "batman",
    target    => "gotham.needs.batman.com",
    timeout   => 0,
};

dies_ok { %t = create_signature($job3); } "command not present"
  or diag explain %t;
 
ok($@ =~ m/run_as and command are needed to sign a job/, 
   "run_as and command are needed to sign a job");

my $job4 = {
    command          => "echo batmobile",
    namespace        => "batcave",
    run_as           => "batman",
    'keyring-userid' => "batman",
    target           => "gotham.needs.batman.com",
    timeout          => 0,
};

my %signature = {
    name => "batman",
    sig  => "batman approves this signature", 
};
%t = create_signature($job4); 
lives_ok { %t = create_signature($job4); } "creating a signature"
    or diag explain %t;

ok(%t, %signature);

