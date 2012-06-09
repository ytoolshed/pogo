#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;

my $nof_tests = 2;
plan tests => $nof_tests;

# use Log::Log4perl qw(:easy);
# Log::Log4perl->easy_init( { level => $DEBUG, layout => "%F{1}:%L> %m%n" } );

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Pogo::One;
use Pogo::Job;
use Pogo::Worker::Task::Command::Remote;

my $scriptbin = "$Bin/../bin";

my $cmd = Pogo::Worker::Task::Command::Remote->new(
    ssh      => "$scriptbin/pogo-test-ssh-sim",
    pogo_pw  => "$scriptbin/pogo-pw",
    command  => "$scriptbin/pogo-test-ls-sim",
    user     => "wombel",
    password => "pass",
    host     => "this.host.does.not.exist",
);

my $cv = AnyEvent->condvar();

$cmd->reg_cb( "on_finish", sub {
    my( $c, $rc ) = @_;

    DEBUG "rc=$rc";
    is $rc, 0, "rc ok";
    like $c->stdout(), qr/foo.*bar/s, "stdout";

    $cv->send();
} );

$cmd->start();

$cv->recv();
