#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;
use Pogo::API;
use Pogo::Dispatcher;
use Pogo::Dispatcher::PonyExpress;

my $nof_tests = 2;
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

$dispatcher->reg_cb( "dispatcher_password_update_received", sub {
    my( $c, $jobid ) = @_;

    is $jobid, "z12345", "password update received";
} );

$dispatcher->reg_cb( "dispatcher_password_update_done", sub {
    my( $c, $jobid ) = @_;

    my $p = $dispatcher->{ password_cache }->get( "z12345" );

    is $p->{ foo }, "bar", "password saved";

    $cv->send();
} );

$dispatcher->start();

my $api_server = Pogo::API->new();
$api_server->standalone();

my $pe = Pogo::Dispatcher::PonyExpress->new(
    peers => [ "0.0.0.0" ],
);

$pe->send( { method    => "password", 
             jobid     => "z12345", 
             passwords => { foo => "bar" } } );

  # start event loop
$cv->recv();
