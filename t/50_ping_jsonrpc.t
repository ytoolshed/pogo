#!/usr/local/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';
use Net::SSLeay qw/sslcat/;
use Log::Log4perl qw/:easy/;

use YAML::Syck qw/LoadFile/;
use FindBin qw/$Bin/;
use JSON;
use IO::Socket::INET;
use Data::Dumper;

use lib "$Bin/lib/";

use PogoTester;

chdir($Bin);

my $js = JSON->new;

# start pogo-dispatcher
ok( PogoTester::start_dispatcher( conf => "$Bin/conf/dispatcher.conf" ) );

my $conf;
eval { $conf = LoadFile("$Bin/conf/dispatcher.conf"); };
ok( !$@, "loadconf" );

ok( $conf->{worker_port}    =~ m/^\d+/, "parse worker port" );
ok( $conf->{rpc_port}       =~ m/^\d+/, "parse rpc port" );
ok( $conf->{authstore_port} =~ m/^\d+/, "parse authstore port" );

foreach my $portname qw/worker_port rpc_port authstore_port/
{
  my $port = $conf->{$portname};

  my @resp;
  eval { @resp = sslcat( '127.0.0.1', $port, $js->encode(["ping"])); };
  ok( !$@, "$portname sslcat" );

  my $pong;
  eval { $pong = $js->decode($resp[0]); };
  ok( !$@ && $pong, "decode $portname" );
  ok( $pong->[0] eq 'pong', "pong $portname" );

}

