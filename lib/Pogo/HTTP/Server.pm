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

use Data::Dumper;

use 5.008;
use common::sense;

use AnyEvent::HTTPD;
use Carp;
use JSON::XS;
use Log::Log4perl qw(:easy);
use MIME::Types qw(by_suffix);
use Template;

my $instance;

sub run
{
  Carp::croak "Server already running" if $instance;
  my $class = shift;
  $instance = {@_};
  bless $instance, $class;

  $instance->{httpd} = AnyEvent::HTTPD->new(
    host => $instance->{bind_address},
    port => $instance->{http_port},
  );

  $instance->{httpd}->reg_cb(
    '/favicon.ico' => sub { handle_favicon(@_); },
    '/api'         => sub { handle_api(@_) },
    ''             => sub { handle_ui(@_) },
  );

  $instance->{tt} ||= Template->new( { INCLUDE_PATH => $instance->{template_path} } );

  INFO sprintf(
    "Accepting HTTP requests on %s:%s",
    $instance->{httpd}->host,
    $instance->{httpd}->port
  );
}

# {{{ handle_async_request

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

# }}}
# {{{ handle_api

sub handle_api
{
  my ( $httpd, $request ) = @_;
  INFO sprintf( 'Received HTTP request for %s from %s:%d - %s',
    $request->url, $request->client_host, $request->client_port, $request->url );

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

# }}}
# {{{ handle_ui

sub handle_ui
{
  my ( $httpd, $request ) = @_;
  my $response_headers = { 'Content-type: text/html', };

  INFO sprintf( 'Received HTTP request for %s from %s:%d',
    $request->url, $request->client_host, $request->client_port );

  # extract our command or jobid from PATH_INFO, falling back to SCRIPT_NAME
  # and trimming the base cgi path from the end. TODO: this may need to be
  # tweaked when running this in a vhost as the PerlHandler for "/"
  my ( undef, $method, @args ) = split( '/', $request->url );

  my $cmd = ( split( m{/}, $method ) )[-1] || 'index';
  my $cmd = "ui_${cmd}";
  my @args;

  # if the requested method isn't valid, see if it's a jobid instead
  eval {
    if ( !$instance->can($cmd) )
    {
      my $jobid;
      eval { $jobid = to_jobid($cmd); };
      if ($jobid)
      {
        $cmd = 'ui_status';
        push @args, $jobid;
      }
      else
      {
        confess "invalid method";
      }
    }

    # execute our requested method or die trying
    $instance->$cmd( $request, @args );
  };

  if ($@)
  {
    ERROR "encountered an error with '$cmd': $@";
    $instance->ui_error( $request, $@ ) if $@;
  }
}

# }}}
# {{{ handle_static

sub ui_static
{
  my ( $self, $request ) = @_;

  my $response_headers = { 'Content-type' => 'application/octet-stream', };

  if ( !defined $instance->{static_path}
    || !-d $instance->{static_path}
    || !-r $instance->{static_path} )
  {
    ERROR "no static path?";
    return $instance->ui_error( $request, "not found" );
  }

  if ( $request->url =~ m{\.\.} )
  {
    ERROR "suspicious url: " . $request->url;
    return $instance->ui_error( $request, "foo" );
  }

  my $path = $request->url;
  $path =~ s/^\/static//;

  my $filepath = $instance->{static_path} . $path;

  if ( !-f $filepath || !-r $filepath )
  {
    return $instance->ui_error( $request, "$path not found" );
  }

  my $size = -s $filepath;

  if ( $size > 102400 )
  {
    return $instance->ui_error( $request, "too big" );
  }

  $response_headers->{'Content-length'} = $size;
  $response_headers->{'Content-type'}   = by_suffix($filepath);

  {
    open my $fh, '<', $filepath
      or confess "couldn't open file";
    $request->respond(
      [ 200, 'OK', $response_headers,
        do { local $/; <$fh>; }
      ]
    );
    close $fh
      or confess "couldn't close file";
  }

  return;
}

# }}}
# {{{ handle_favicon

sub handle_favicon
{
  my ( $httpd, $request ) = @_;
  $request->respond(
    [ 301,
      'Moved Permanently',
      { 'Location' => '/static/favicon.png' },
      '<html><head><title>Moved Permanently</title></head><body><a href="/static/favicon.png">Moved Permanently</a></body></html>'
    ]
  );
}

# }}}

sub ui_status
{
}

sub ui_index
{
  my ( $self, $request, @args ) = @_;

  my $data = {};

  $instance->{tt}->process(
    'index.tt',
    $data,
    sub {
      my $output = shift;
      $request->respond( [ 200, 'OK', { 'Content-type' => 'text/html' }, $output ] );
    },
  );
}

sub ui_error
{
  my ( $self, $request, $error ) = @_;
  DEBUG Dumper [ $error, caller ];
  $instance->{tt}->process(
    'error.tt',
    { error => $error, page_title => 'ERROR', },
    sub {
      my $output = shift;
      $request->respond( [ 500, 'ERROR', { 'Content-type' => 'text/html' }, $output ] );
    },
    )
    or $request->respond(
    [ 500, 'ERROR', { 'Content-type' => 'text/plain' }, "an unknown error occurred" ] );
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
