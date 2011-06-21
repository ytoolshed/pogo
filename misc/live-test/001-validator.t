# Validator tests
use warnings;
use strict;
use Test::More;
use HTTP::Request::Common;
use LWP::UserAgent;
use Sysadm::Install qw(:all);
use lib 'lib';
use PogoLiveTest;

my $file = "data/test.yaml";
my $content = slurp $file;

our $validator_url = "$ENV{POGO_URL}/pogo-validator";

    # post to validator
my $ua    = LWP::UserAgent->new();
my $req   = POST $validator_url, [ 'new' => $content, 'file' => $file ];

my $resp  = $ua->request( $req );

print $resp->as_string();

plan tests => 1;

ok 1, "first";
