package Pogo::HTTP::Server;

# Copyright (c) 2010, Yahoo! Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use 5.008;
use common::sense;

use AnyEvent::HTTPD;
use Carp;
use JSON::XS;
use Log::Log4perl qw(:easy);

my $instance;

sub run
{
  Carp::croak "Server already running" if $instance;
  my $class = shift;
  $instance = {@_};
  bless $instance, $class;

  $instance->{httpd} = AnyEvent::HTTPD->new(
    host => $instance->{host},
    port => $instance->{port}
  );

  $instance->{httpd}->reg_cb(
    '/api'   => sub { handle_request(@_) },
    '/async' => sub { handle_async_request(@_) },
  );
}

sub handle_async_request
{
  my ( $httpd, $request ) = @_;
  if ( $request->parm('r') )
  {
    INFO sprintf( 'Received async HTTP request for %s from %s:%d - %s',
      $request->url, $request->client_host, $request->client_port, $request->parm('r') );
  }
  else
  {
    INFO sprintf( 'Received async HTTP request for %s from %s:%d',
      $request->url, $request->client_host, $request->client_port );
  }

  my $response_format = $request->parm('format') || 'json';
  my $response_headers = {
      'Content-Type' => $response_format eq 'yaml'
    ? 'text/plain'
    : 'text/javascript'
  };

  my $response_callback = sub {
    my ($response) = @_;

    $response->set_format($response_format);
    $response->set_callback( $request->parm('c') ) if $request->parm('c');
    $response->set_pushvar( $request->parm('v') )  if $request->parm('v');

    if ( $response->is_success )
    {
      $request->respond( [ 200, 'OK', $response_headers, $response->content ] );
    }
    else
    {
      $request->respond( [ 500, 'ERROR', $response_headers, $response->content ] );
    }
  };

  eval {
    my ( undef, undef, $version, $method ) = split( '/', $request->url );
    $version = uc($version);
    die "Unsupported version '$version'" unless $version =~ /^v\d+/i;

    # Dynamically load the API module
    my $class = "Pogo::API::$version";
    eval "require $class";
    die $@ if $@;

    if ($method)
    {
      ();    # TODO: Add supported REST methods
    }
    else     # RPC request
    {
      DEBUG "request=" . $request->parm('r');
      if ( $request->parm('r') )
      {
        die "c/v mutually exclusive"
          if $request->parm('c') && $request->parm('v');
        my $req = JSON::XS::decode_json( $request->parm('r') );
        my ( $action, @args ) = @$req;
        $class->$action( @args, $response_callback );
      }
    }
  };
  if ($@)
  {
    chomp( my $errmsg = $@ );
    ERROR $errmsg;
    my $error = Pogo::Engine::Response->new;
    $error->set_format($response_format);
    $error->set_error($errmsg);
    $request->respond( [ 500, 'OK', $response_headers, $error->content ] );
  }
}

sub handle_request
{
  my ( $httpd, $request ) = @_;
  INFO sprintf( 'Received HTTP request for %s from %s:%d',
    $request->url, $request->client_host, $request->client_port );

  # Set these to some defaults in case an exception is raised.
  my $response         = Pogo::Engine::Response->new;
  my $response_format  = $request->parm('format') || 'json';
  my $response_headers = {
      'Content-Type' => $response_format eq 'yaml'
    ? 'text/plain'
    : 'text/javascript'
  };

  eval {
    my ( undef, undef, $version, $method ) = split( '/', $request->url );
    $version = uc($version);
    die "Unsupported version '$version'" . $request->url unless $version =~ /^v\d+/i;

    # Dynamically load the API module
    my $class = "Pogo::API::$version";
    eval "require $class";
    die $@ if $@;

    if ($method)
    {
      ();    # TODO: Add supported REST methods
    }
    else     # RPC request
    {
      DEBUG "request=" . $request->parm('r');
      if ( $request->parm('r') )
      {
        die "c/v mutually exclusive"
          if $request->parm('c') && $request->parm('v');
        my $req = JSON::XS::decode_json( $request->parm('r') );
        my ( $action, @args ) = @$req;
        $response = $class->$action(@args);
        $response->add_header( action => $action );
        $response->set_format($response_format);
        $response->set_callback( $request->parm('c') ) if $request->parm('c');
        $response->set_pushvar( $request->parm('v') )  if $request->parm('v');
        $request->respond( [ 200, 'OK', $response_headers, $response->content ] );
      }
    }
  };
  if ($@)
  {
    chomp( my $errmsg = $@ );
    ERROR $errmsg;
    my $error = Pogo::Engine::Response->new;
    $error->set_format($response_format);
    $error->set_error($errmsg);
    $request->respond( [ 500, 'OK', $response_headers, $error->content ] );
  }
}

1;

=pod

=head1 NAME

  CLASSNAME - SHORT DESCRIPTION

=head1 SYNOPSIS

CODE GOES HERE

=head1 DESCRIPTION

LONG_DESCRIPTION

=head1 METHODS

B<methodexample>

=over 2

methoddescription

=back

=head1 SEE ALSO

L<Pogo::Dispatcher>

=head1 COPYRIGHT

Apache 2.0

=head1 AUTHORS

  Andrew Sloane <asloane@yahoo-inc.com>
  Michael Fischer <mfischer@yahoo-inc.com>
  Nicholas Harteau <nrh@yahoo-inc.com>
  Nick Purvis <nep@yahoo-inc.com>
  Robert Phan <rphan@yahoo-inc.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
