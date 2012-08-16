#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;
use Sysadm::Install qw( slurp );

my $nof_tests = 4;
plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init( { level => $DEBUG } );

use Pogo::Util::SSH::Agent;

my $agent = Pogo::Util::SSH::Agent->new();

$agent->start( sub {
    my( $auth_sock, $agent_pid ) = @_;

    DEBUG "auth_sock is $auth_sock";
    $agent->key_add( slurp( "$Bin/keys/nopp" ) );
    # ...
} );

my $cv = AnyEvent->condvar();

my $timer = AnyEvent->timer( after => 2, 
    cb => sub {
        $cv->send();
    } );

$cv->recv();

#$agent->key_add( $private_key, sub {
#    $rc ) = @_;
#        # ...
#} );
#

$agent->shutdown();
