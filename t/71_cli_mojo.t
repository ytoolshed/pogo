#!/usr/local/bin/perl -w
# $Id$

use strict;
use warnings;

use Test::More tests => 1;

use HTTP::Request::Common qw/GET/;
use LWP::UserAgent;
use Mojolicious::Lite;

use FindBin qw($Bin);
use lib "$Bin/../lib/";
use lib "$Bin/../../server/lib/";

# set up mojolicious
app->log->level('error');

get '/foo' => sub {
  my $self = shift;
  $self->render(text => 'bar');
};

# start mojolicious
my $pid = fork();
if ( $pid == 0 )
{
  shagadelic('daemon');
}
else
{
  print "Waiting for server to start\n";
  sleep 1;

  my $ua    = LWP::UserAgent->new;
  my $req   = GET 'http://localhost:3000/foo';
  my $resp  = $ua->request($req);

  print "Killing server\n";
  kill 9, $pid;

  is( $resp->content, 'bar', 'Mojolicious' );
}
