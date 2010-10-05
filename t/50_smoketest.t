#!/usr/local/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';
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

foreach my $port ( $conf->{worker_port}, $conf->{rpc_port}, $conf->{authstore_port} )
{

  my $handle = IO::Socket::INET->new(
    PeerAddr => '127.0.0.1',
    PeerPort => $port,
    Proto    => 'tcp',
    Timeout  => 15,
  );

  ok( defined $handle, "connect to $port" );
  my $foo;
  eval { $foo = $handle->connected };
  ok( !$@ && $foo, "$port is connected" );

  my $ping = $js->encode( ["ping"] );

  my $len = 31337;
  eval { $len = $handle->send($ping); };
  ok( length($ping) == $len && !$@, "$port send length" );
  ok( !undef $handle, "undef handle" );

  my $resp;
  my $data;
  eval { $resp = $handle->recv( $data, 100 ); };
  ok( !$@ && $resp eq '127.0.0.1', "recv $port" );

  my $pong;
  eval { $pong = $js->decode($data); };
  ok( !$@ && $pong, "decode $port" );
  ok( $pong->[0] eq 'pong', "pong $port" );

  print Dumper $data;
  print Dumper $resp;
}

