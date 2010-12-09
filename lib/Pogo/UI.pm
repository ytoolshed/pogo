package Pogo::UI;

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
use warnings;
use strict;

use Apache2::RequestRec qw();   # content_type
use Apache2::RequestIO qw();    # print
use Apache2::RequestUtil qw();  # dir_config
use Apache2::Const -compile=> ':common';

use CGI;
use Template;

sub handler
{
  __PACKAGE__->new( shift )->start();
}

sub new
{
  my ( $class, $r ) = @_;

  # APR::Table is just broken, so we have to do this individually
  my $conf = {
    'template_path' => $r->dir_config( 'TEMPLATE_PATH' )  || '.',
    'base_cgi_path' => $r->dir_config( 'BASE_CGI_PATH' )  || '/'
  };

  my $self = {
    'r'     => $r,
    'cgi'   => CGI->new,
    'tt'    => Template->new( { INCLUDE_PATH => $conf->{template_path} } ),
    'pc'    => undef,
    'conf'  => $conf
  };

  bless $self, $class;
}

sub start
{
  my ( $self ) = @_;

  $self->content_type( 'text/plain' );

  # extract our command or jobid from PATH_INFO, falling back to SCRIPT_NAME
  my $cmd   = ( split( /\//, $ENV{PATH_INFO} || $ENV{SCRIPT_NAME} ) )[ -1 ] || 'index';
  my $xcmd  = "cmd_${cmd}";

  # see if the requested method is valid
  if (! $self->can( $xcmd ) )
  {
    # TODO: grab jobid and use cmd_status
    $xcmd = 'cmd_index';
  }

  # execute our requested method or die trying
  eval { $self->$xcmd(); };
  $self->error( $@ ) if $@;

  # everything is sunshine and rainbows
  return Apache2::Const::OK;
}

sub content_type
{
  my ( $self, $type ) = @_;
  return $self->{r}->content_type( $type );
}

sub process_template
{
  my ( $self, $template, $data ) = @_;

  # include global configuration items in the template data
  foreach my $key (keys %{$self->{conf}})
  {
    $data->{$key} = $self->{conf}->{$key} unless defined $data->{$key};
  }

  # output our processed template
  $self->{tt}->process( $template, $data ) || die $self->{tt}->error();
}

sub error
{
  my ( $self, $error ) = @_;

  # error template with error message
  $self->process_template( 'error.tt', { error => $error, page_title => 'Error' } );
}

sub cmd_index
{
  my ( $self ) = @_;

  $self->process_template( 'index.tt', {} );
}

1;
