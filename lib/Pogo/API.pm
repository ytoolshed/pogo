package Pogo::API;

# Copyright (c) 2010-2011 Yahoo! Inc. All rights reserved.
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

  # before we create our instance, see if we have an alternate config dir
  $Pogo::Common::CONFIGDIR = $r->dir_config( 'POGO_CONFIG_DIR' )
    if $r->dir_config( 'POGO_CONFIG_DIR' );

  my $class = 'Pogo::API::' . $version;
  my $api   = $class->instance;

  if ( !$c->param('format') )
  {
    $r->content_type('text/javascript');
  }
  elsif ( $c->param('format') eq 'yaml' )
  {
    $r->content_type('text/plain');
  }
  else
  {
    $r->content_type('text/javascript');
  }


  # non-RPC requests
  if ( !$c->param('r') )
  {
    my $method = shift @path;
    if ( $method && $api->can( 'api_' . $method ) )
    {
      $method = 'api_' . $method;
      my $response = $api->$method( $c->Vars );
      $response->set_format( $c->param('format') );
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
    return throw_error( $c, 'Unknown request' );
  }

  # heavy-lifting - now we're RPC
  my $req;
  eval { $req = $js->decode( $c->param('r') ) };

  if ($@)
  {
    return throw_error( $c, $@ );
  }

  if ( $c->param('c') && $c->param('v') )
  {
    return throw_error( $c, "c/v mutually exclusive" );
  }

  # so now we try to use api_foo in the versioned API::Vx module
  # are we really just re-implementing AUTOLOAD here?
  # perhaps rpc should be AUTOLOAD'd and API.pm should just
  # pass through requests.

  my $response;
  eval { $response = $api->rpc(@$req) };
  if ($@)
  {
    return throw_error( $c, $@ );
  }

  $response->set_format( $c->param('format') );
  $response->set_callback( $c->param('c') )
    if $c->param('c');
  $response->set_pushvar( $c->param('v') )
    if $c->param('v');

  print $response->content;
  return $Apache2::Const::HTTP_OK;
}

sub throw_error
{
  my ( $c, $errmsg ) = @_;
  ERROR $errmsg;
  my $error = Pogo::Engine::Response->new;

  $error->set_format( $c->param('format') );
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

  Andrew Sloane <andy@a1k0n.net>
  Ian Bettinger <ibettinger@yahoo.com>
  Michael Fischer <michael+pogo@dynamine.net>
  Mike Schilli <m@perlmeister.com>
  Nicholas Harteau <nrh@hep.cat>
  Nick Purvis <nep@noisetu.be>
  Robert Phan <robert.phan@gmail.com>
  Srini Singanallur <ssingan@yahoo.com>
  Yogesh Natarajan <yogesh_ny@yahoo.co.in>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
