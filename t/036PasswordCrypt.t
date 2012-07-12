#!/usr/local/bin/perl
use strict;
use warnings;
use Test::More;
use Sysadm::Install qw( slurp );
use Pogo::Client::Util qw( password_encrypt password_decrypt );

my $nof_tests = 4;
plan tests => $nof_tests;

BEGIN {
    use FindBin qw( $Bin );
    use lib "$Bin/lib";
    use PogoTest;
}

use Log::Log4perl qw(:easy);

my $cert    = "$Bin/certs/worker.crt";
my $privkey = "$Bin/certs/worker.key";

my $crypt = password_encrypt( $cert, "abc" );

ok length($crypt) > 100, "password encrypted";

my $clear = password_decrypt( $privkey, $crypt );

is $clear, "abc", "clear text";

my $cert_data = slurp $cert;

$crypt = password_encrypt( $cert, "abc" );

ok length($crypt) > 100, "password encrypted";

my $privkey_string = slurp $privkey;

$clear = password_decrypt( \$privkey_string, $crypt );
is $clear, "abc", "clear text";
