#!/usr/bin/env perl -w
use strict;
use warnings;

use Test::More tests => 7;
use Log::Log4perl qw(:easy);
use Cwd;

my $cwd = cwd();
my $abs = "file://$cwd";

use Pogo::Client::Commandline;

*uri_to_absuri = *Pogo::Client::Commandline::uri_to_absuri;

is(uri_to_absuri("blah"), "$abs/blah", "base");
is(uri_to_absuri("blah", "."), "$abs/blah", "base");
is(uri_to_absuri("blah", "$cwd/"), "$abs/blah", "base");

is(uri_to_absuri("foo/blah"), "$abs/foo/blah", "single path");
is(uri_to_absuri("foo/blah", "."), "$abs/foo/blah", "single path");
is(uri_to_absuri("foo/blah", "$cwd/"), "$abs/foo/blah", "single path");

is(uri_to_absuri("/foo/bar/baz"), "file:///foo/bar/baz", "abs path");

