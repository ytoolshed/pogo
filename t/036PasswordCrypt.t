#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;
use Pogo::Client::Util qw( password_encrypt );

my $nof_tests = 1;
plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Log::Log4perl qw(:easy);

my $cert = "$Bin/certs/worker.crt";
my $crypt = password_encrypt( $cert, "abc" );

ok length($crypt) > 100, "password encrypted";
