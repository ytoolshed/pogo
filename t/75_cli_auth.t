#!/usr/local/bin/perl -w
# $Id: 20_cli_auth.t 268881 2010-03-08 21:06:13Z nharteau $;

use strict;
use warnings;

use Test::More tests => 6;
use Log::Log4perl qw(:easy);

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use lib "$Bin/../../server/lib/";

Log::Log4perl::init("$Bin/t.log4perl");

use_ok('Pogo::Client');
use_ok('Pogo::Client::CLI::Auth');

SKIP:
{
  skip "Skipping interactive tests", 3 unless ( -t STDIN );

  $|=1;

  # t3
  print STDERR '# Please enter "foo": ';
  ok( Pogo::Client::CLI::Auth::get_password('') eq 'foo', "prompt for 'foo'" );

  # t4
  print STDERR "# Enter your local unix password: ";
  ok( Pogo::Client::CLI::Auth::check_password(), "check_password() - fails on some freebsd versions" );

  # t5
  print STDERR "# Enter your local unix password (again): ";
  my $pass = Pogo::Client::CLI::Auth::get_password('');
  ok( Pogo::Client::CLI::Auth::check_password( scalar getpwuid($<), $pass ),
    "check_password(args) - fails on some freebsd versions" );
  print STDERR "                                          \r";
}

# t6 (your password better not be 'mypassword')
ok( !Pogo::Client::CLI::Auth::check_password( scalar getpwuid($<), 'mypassword' ), "check_password(mypassword)" );


