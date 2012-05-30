
use warnings;
use strict;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";
use JSON qw( from_json );
use Pogo::API;
use PogoFake;
use PogoTest;
use AnyEvent::HTTP;
use Test::More;
use Log::Log4perl qw(:easy);
use Getopt::Std;
use Pogo::Defaults qw(
  $POGO_DISPATCHER_CONTROLPORT_PORT
  $POGO_DISPATCHER_CONTROLPORT_HOST
  $POGO_API_TEST_PORT
  $POGO_API_TEST_HOST
);

my $pogo = PogoFake->new();

$pogo->reg_cb( dispatcher_controlport_up  => sub {
    my( $c ) = @_;

    ok( 1, "dispatcher controlport up #1" );
});

$pogo->reg_cb( dispatcher_wconn_worker_connect  => sub {
    my( $c ) = @_;

    http_get 
     "http://$POGO_DISPATCHER_CONTROLPORT_HOST:" .
     "$POGO_DISPATCHER_CONTROLPORT_PORT/status", 
     sub { 
            my( $html ) = @_;
 
            DEBUG "Response from server: [$html]";

            my $data = from_json( $html );

            my @workers = @{ $data->{ workers } };

            is scalar @workers, 1, "One worker connected \#2";
            like $workers[0], 
              qr/$POGO_DISPATCHER_CONTROLPORT_HOST:\d+$/, "worker details \#3";
 
            is $data->{ pogo_version }, $Pogo::VERSION, "pogo version \#4";
     };
});

  # Start up test API server
my $api = Plack::Handler::AnyEvent::HTTPD->new(
    host => $POGO_API_TEST_HOST,
    port => $POGO_API_TEST_PORT,
    server_ready => 
      tests( "http://$POGO_API_TEST_HOST:$POGO_API_TEST_PORT" ),
);

$api->register_service( Pogo::API->app() );

plan tests => 18;

$pogo->start();

# This gets called once the API server is up
sub tests {
    my( $base_url ) = @_;

    return sub {

        # GET /v1/jobs (list jobs)
        http_get "$base_url/v1/jobs", sub {
            my( $html, $hdr ) = @_;
            my $data = from_json( $html );

            is $data->{ response }->{ jobs }->[0]->{ jobid }, 'p0000000008',
            "first job returned from 'GET /jobs' is p0000000008 \#5";
        };

        # GET /v1/jobs/:jobid (get job info)
        http_get "$base_url/v1/jobs/p0000000006", sub {
            my( $html, $hdr ) = @_;
            my $data = from_json( $html );

            is $data->{ response }->{ job }->{ command }, 'sudo apachectl -k restart',
            "command for p0000000006 reported correctly \#6";
        };

        # GET /v1/jobs/:jobid/log (get job log)
        http_get "$base_url/v1/jobs/p0000000008/log", sub {
            my( $html, $hdr ) = @_;
            my $data = from_json( $html );

            my $first_log_entry = $data->{ response }->{ joblog }->[0];
            my $last_log_entry = $data->{ response }->{ joblog }->[-1];

            ok $first_log_entry->{range},               "first log entry range exists \#7";
            is $first_log_entry->{type},    'jobstate', "first log entry type is 'jobstate' \#8";
            is $first_log_entry->{state},  'gathering', "first log entry state is 'gathering' \#9";
            ok $first_log_entry->{message},             "first log entry message exists \#10";

            is $last_log_entry->{type},   'jobstate',  "last log entry type is 'jobstate' \#11";
            is $last_log_entry->{state},  'finished',  "last log entry state is 'finished' \#12";
            ok $last_log_entry->{message},             "last log entry message exists \#13";
        };

        # GET /v1/jobs/:jobid/hosts (get hosts for job)
        http_get "$base_url/v1/jobs/p0000000004/hosts", sub {
            my( $html, $hdr ) = @_;
            my $data = from_json( $html );

            ok $data->{ response }->{ hosts }->{ 'host3.pub.example.com' },
            "host3.pub.example.com returned as one of the target hosts \#14";

            is scalar ( keys %{ $data->{ response }->{ hosts } } ), 4,
            "job p0000000004 has 4 hosts \#15";

            is $data->{ response }->{ hosts }->{ 'host2.pub.example.com' }->{ state }, 'finished',
            "job p0000000004, host host2.pub.example.com has status 'finished' \#16";
        };

        # GET /v1/jobs/:jobid/hosts/:host (get host output)
        http_get "$base_url/v1/jobs/p0000000001/hosts/some.host.example.com", sub {
            my( $html, $hdr ) = @_;
            my $data = from_json( $html );

          TODO: {
              local $TODO = "/jobs/[jobid]/hosts/[hostname] not yet implemented";
              is $data->{ output }->[0], 'expected host output',
              "output of command to some.host.example.com as expected \#17";
            }
        };

        # GET /v1/jobs/last/:username (get most recent job for a given user)
        http_get "$base_url/v1/jobs/last/gandalf", sub {
            my( $html, $hdr ) = @_;
            my $data = from_json( $html );

          TODO: {
              local $TODO = "/jobs/last/[user] not yet implemented";
              is $data->{ command }, 'whoami',
              "find correct last job by gandalf \#18";
            }
        };
    };
}
