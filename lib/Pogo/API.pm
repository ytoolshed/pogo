package Pogo::API;

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

use strict;
use warnings;

use Apache2::Const;
use CGI;
use JSON;
use Log::Log4perl qw(:easy);
use YAML::XS qw();

use Pogo::API::V3;

our $VERSION = '0.0.2';

sub handler
{
  my $r  = shift;
  my $c  = CGI->new();
  my $js = JSON->new();

  my ( undef, @path ) = split '/', $r->path_info;    # throw away leading null
  my $thing = shift @path;

  my $version = 'V3';                                # first public release

  if ( $thing && $thing =~ m/^v\d+$/i )
  {
    $version = uc($thing);
  }

  my $class = 'Pogo::API::' . $version;
  my $api   = $class->instance;

  # non-RPC requests
  if ( !$c->param('r') )
  {
    my $method = shift @path;
    if ( $method && $api->can( 'api_' . $method ) )
    {
      $method = 'api_' . $method;
      my $response = $api->$method( $c->Vars );
      $response->set_format( $c->param('format') );
      $r->content_type( $response->format eq 'json' ? 'text/javascript' : 'text/plain' );
      print $response->content;
      return $Apache2::Const::HTTP_OK;
    }
    else
    {
      $r->content_type('text/html');
      print $c->start_html( -title => 'Pogo Status' );
      my $pong = $api->rpc( 'ping', 'pong' );
      $pong->set_format('yaml');
      print '<pre>';
      print $pong->content;
      print '</pre>';

      return $pong->is_success ? $Apache2::Const::HTTP_OK : $Apache2::Const::SERVER_ERROR;
    }
    return throw_error( $r, $c, 'Unknown request' );
  }

  # heavy-lifting - now we're RPC
  my $req;
  eval { $req = $js->decode( $c->param('r') ) };

  if ($@)
  {
    return throw_error( $r, $c, $@ );
  }

  DEBUG "requested method: " . $req->[0];

  if ( $c->param('c') && $c->param('v') )
  {
    return throw_error( $r, $c, "c/v mutually exclusive" );
  }

  # so now we try to use api_foo in the versioned API::Vx module
  # are we really just re-implementing AUTOLOAD here?
  # perhaps rpc should be AUTOLOAD'd and API.pm should just
  # pass through requests.

  my $response;
  eval { $response = $api->rpc(@$req) };
  if ($@)
  {
    return throw_error( $r, $c, $@ );
  }

  $response->set_format( $c->param('format') );
  $response->set_callback( $c->param('c') )
    if $c->param('c');
  $response->set_pushvar( $c->param('v') )
    if $c->param('v');

  $r->content_type( $response->format eq 'json' ? 'text/javascript' : 'text/plain' );
  print $response->content;
  return $Apache2::Const::HTTP_OK;
}

sub throw_error
{
  my ( $r, $c, $errmsg ) = @_;
  ERROR $errmsg;
  my $error = Pogo::Engine::Response->new;

  $error->set_format( $c->param('format') );
  $r->content_type( $error->format eq 'json' ? 'text/javascript' : 'text/plain' );
  $error->set_error($errmsg);

  print $error->content;
  return $Apache2::Const::HTTP_OK;
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
