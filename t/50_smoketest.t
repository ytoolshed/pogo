#!/usr/local/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';
use LWP::UserAgent;
use YAML::Syck qw/LoadFile/;
use FindBin qw/$Bin/;
use JSON;

use lib "$Bin/lib/";

use PogoTester;

chdir($Bin);

my $ua = LWP::UserAgent->new();
my $js = JSON->new;

# start pogo-dispatcher
ok( PogoTester::start_dispatcher( conf => "$Bin/conf/dispatcher.conf" ) );

my $conf;
eval { $conf = LoadFile("$Bin/conf/dispatcher.conf"); };
ok( !$@ );

ok( $conf->{worker_port}    =~ m/^\d+/ );
ok( $conf->{rpc_port}       =~ m/^\d+/ );
ok( $conf->{authstore_port} =~ m/^\d+/ );

