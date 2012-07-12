#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;
use Pogo::API;
use Pogo::Dispatcher;
use Pogo::Dispatcher::PonyExpress;
use Pogo::Defaults qw(
    @POGO_DISPATCHER_TEST_CONTROLPORT_NETLOCS
    @POGO_DISPATCHER_TEST_WORKERCONN_NETLOCS
);

my $nof_tests = 4;
plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Log::Log4perl qw(:easy);
# Log::Log4perl->easy_init( { level => $DEBUG } );

my $cv = AnyEvent->condvar();

my @dispatchers = ();

my @dispatcher_cps = @POGO_DISPATCHER_TEST_CONTROLPORT_NETLOCS;
my @dispatcher_wcs = @POGO_DISPATCHER_TEST_WORKERCONN_NETLOCS;

my $pw_updates_expected = 2;

for ( 1 .. scalar @POGO_DISPATCHER_TEST_CONTROLPORT_NETLOCS ) {

    my( $cp_host, $cp_port ) = split /:/, shift @dispatcher_cps;
    my( $wc_host, $wc_port ) = split /:/, shift @dispatcher_wcs;

    my $dispatcher = Pogo::Dispatcher->new(
        controlport_host => $cp_host,
        controlport_port => $cp_port,
        workerconn_host  => $wc_host,
        workerconn_port  => $wc_port,
    );

    push @dispatchers, $dispatcher;

    $dispatcher->reg_cb( "dispatcher_password_update_received", sub {
        my( $c, $jobid ) = @_;
    
        is $jobid, "z12345", "password update received";
    } );

    $dispatcher->reg_cb( "dispatcher_password_update_done", sub {
        my( $c, $jobid ) = @_;
    
        my $p = $dispatcher->{ password_cache }->get( "z12345" );
    
        is $p->{ foo }, "bar", "password saved";
    
        if( --$pw_updates_expected == 0 ) {
            $cv->send();
        }
    } );

    $dispatcher->start();
}

my $api_server = Pogo::API->new();
$api_server->standalone();

my $pe = Pogo::Dispatcher::PonyExpress->new(
    peers => [ @POGO_DISPATCHER_TEST_CONTROLPORT_NETLOCS ],
);

$pe->send( { method    => "password", 
             jobid     => "z12345", 
             passwords => { foo => "bar" } } );

  # start event loop
$cv->recv();
