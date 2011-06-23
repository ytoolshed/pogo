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

plan tests => 3;

# print STDERR $resp->as_string();

ok 1, "first";
is $resp->is_success(), 1, "pogo-validator successful";
like $resp->as_string(), qr/"status":"OK"/, "status ok";
