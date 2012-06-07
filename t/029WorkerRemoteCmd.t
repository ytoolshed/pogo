#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;

my $nof_tests = 1;
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
use Pogo::Util::Bucketeer;
use Pogo::Worker::Task::Command::Remote;

my $cmd = Pogo::Worker::Task::Command::Remote->new(
    command => "ls -l",
    user    => "wombel",
    host    => "this.host.does.not.exist",
);

my $cv = AnyEvent->condvar();

$cmd->reg_cb( "on_finish", sub {
    my( $c, $rc ) = @_;

    DEBUG "rc=$rc";
    ok $rc, "rc != 0";

    $cv->send();
} );

$cmd->start();

$cv->recv();
