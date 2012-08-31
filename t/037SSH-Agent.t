#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;
use Sysadm::Install qw( slurp );
use POSIX qw( PIPE_BUF );

my $nof_tests = 3;
plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
}

use Log::Log4perl qw(:easy);
# Log::Log4perl->easy_init( { level => $DEBUG, layout => "%F{1}-%L: %m%n" } );

use Pogo::Util::SSH::Agent;

my $agent = Pogo::Util::SSH::Agent->new();

my $cv = AnyEvent->condvar();

$agent->reg_cb( "ssh_key_added_ok", sub {
    ok 0, "long key accepted";
    $cv->send();
} );

$agent->reg_cb( "ssh_key_added_fail", sub {
    ok 1, "long key rejected";
    $cv->send();
} );

$agent->reg_cb( "shutdown_complete", sub {
        ok 1, "shutdown_complete";
} );

$agent->reg_cb( "ssh_agent_ready", sub {
    my( $auth_sock, $agent_pid ) = @_;

    ok 1, "auth socket reported";

    $agent->key_add( "x" x ( PIPE_BUF + 1 ) );
} );

$agent->start();

$cv->recv();

$agent->shutdown();
