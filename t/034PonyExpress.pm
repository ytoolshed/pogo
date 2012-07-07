#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;
use Pogo::API;
use Pogo::Dispatcher;
use Pogo::Dispatcher::PonyExpress;

my $nof_tests = 1;
plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Log::Log4perl qw(:easy);
# Log::Log4perl->easy_init( { level => $DEBUG } );

my $cv = AnyEvent->condvar();

my $dispatcher = Pogo::Dispatcher->new();

$dispatcher->reg_cb( "dispatcher_controlport_message_received", sub {
    my( $c, $data ) = @_;

    is $data, "hello", "message received";
    $cv->send();
} );

$dispatcher->start();


my $api_server = Pogo::API->new();
$api_server->standalone();

my $pe = Pogo::Dispatcher::PonyExpress->new(
    peers => [ "0.0.0.0" ],
);

$pe->send( "hello" );

  # start event loop
$cv->recv();
