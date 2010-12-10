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
use JSON;
use List::Util qw(min max);
use Log::Log4perl qw(:easy);
use Template;

use Pogo::Client;

our $HOST_COUNT_CACHE = {};

sub handler
{
  __PACKAGE__->new( shift )->start();
}

sub new
{
  my ( $class, $r ) = @_;

  # APR::Table is just broken, so we have to do this individually
  my $conf = {
    'pogo_api'      => $r->dir_config( 'POGO_API' )       || 'http://localhost:80/pogo',
    'template_path' => $r->dir_config( 'TEMPLATE_PATH' )  || '.',
    'base_cgi_path' => $r->dir_config( 'BASE_CGI_PATH' )  || '/',
    'jobid_offset'  => $r->dir_config( 'JOBID_OFFSET' )   || 0,
    'show_logger'   => $r->dir_config( 'SHOW_LOGGER' )    || 0
  };

  my $self = {
    'r'     => $r,
    'cgi'   => CGI->new,
    'json'  => JSON->new,
    'tt'    => Template->new( { INCLUDE_PATH => $conf->{template_path} } ),
    'pc'    => undef,
    'conf'  => $conf
  };

  bless $self, $class;
}

sub start
{
  my ( $self ) = @_;

  $self->content_type( 'text/html' );

  # extract our command or jobid from PATH_INFO, falling back to SCRIPT_NAME
  # and trimming the base cgi path from the end. TODO: this may need to be
  # tweaked when running this in a vhost as the PerlHandler for "/"
  my $script    = $ENV{PATH_INFO} || $ENV{SCRIPT_NAME};
  my $cgi_path  = $self->{conf}->{base_cgi_path};
  $script =~ s/${cgi_path}$//;
  my $cmd       = ( split( /\//, $script ) )[ -1 ] || 'index';
  my $xcmd      = "cmd_${cmd}";

  # if the requested method isn't valid, see if it's a jobid instead
  if ( ! $self->can( $xcmd ) )
  {
    my $jobid;
    eval { $jobid = $self->to_jobid( $cmd ); };
    if ( $jobid )
    {
      $self->{cgi}->param( 'jobid', $jobid );
      $xcmd = 'cmd_status';
    }
    else
    {
      # not a valid method or a jobid, bail
      $self->error( "Invalid request method: $cmd" );
      return Apache2::Const::OK;
    }
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

sub pogo_client
{
  my ( $self ) = @_;
  unless ( $self->{pc} )
  {
    $self->{pc} = Pogo::Client->new( $self->{conf}->{pogo_api} );
  }
  return $self->{pc};
}

sub to_jobid
{
  my ( $self, $jobid ) = @_;

  my $p = 'p';
  my $i;

  if ( $jobid eq 'last' )
  {
    # TODO: how do we determine user?
  }

  if ( $jobid =~ m/^([a-z]+)(\d+)$/ )
  {
    $p = $1;
    $i = $2;
  }
  elsif ( $jobid =~ m/^(\d+)$/ )
  {
    $i = $1;
  }

  my $new_jobid;
  if ( defined $i )
  {
    $new_jobid = sprintf "%s%010d", $p, $i;
  }
  else
  {
    LOGDIE "No jobid found\n";
  }

  return $new_jobid;
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

  my $jobs_per_page = $self->{cgi}->param('max') || 25;

  # initialize filters
  my %filters;
  foreach my $f (qw(user state target))
  {
    my $value = $self->{cgi}->param($f);
    $filters{$f} = $value if defined $value;
  }

  # calculate the offset
  my $req_page = $self->{cgi}->param('cur') || 1;
  my $offset   = ( $req_page - 1 ) * $jobs_per_page;
  $filters{offset} = $offset if $offset;

  # determine the total number of jobs
  my $max_jobid = $self->_list_jobs( offset => 0, limit => 2 )->[0]->{jobid};
  my $num_jobs  = $jobs_per_page;
  if ($max_jobid =~ m/^p(\d+)$/)
  {
    $num_jobs = int( $1 ) - $self->{conf}->{jobid_offset};
  }

  # build our data
  my $data = {
    page_title    => 'Pogo UI',
    jobs          => $self->_list_jobs( page => $req_page, limit => $jobs_per_page, %filters ),
    running_jobs  => $self->_list_jobs( state => 'running' ),
    jobs_per_page => $jobs_per_page,
    num_jobs      => $num_jobs,
    req_page      => $req_page,
    %filters
  };

  $data->{pager} = $self->_paginate( $data );

  $self->process_template( 'index.tt', $data );
}

sub cmd_status
{
  my ( $self ) = @_;

  my $jobid = $self->{cgi}->param( 'jobid' ) || LOGDIE "No jobid provided\n";
  my $resp  = $self->pogo_client()->jobinfo( $jobid );
  if ( ! $resp->is_success )
  {
    LOGDIE "Couldn't fetch jobinfo for $jobid: " . $resp->status_msg . "\n";
  }

  my $data = {
    page_title  => 'Pogo UI: ' . $jobid,
    jobid       => $jobid,
    jobinfo     => $resp->record
  };

  $self->process_template( 'status.tt', $data );
}

sub _list_jobs
{
  my ( $self, %filters ) = @_;

  my $req_page = delete $filters{page} || 1;

  my $resp = $self->pogo_client()->listjobs( %filters );

  # reformat the output
  my @jobs = $resp->records;
  my $num_jobs = @jobs > 0 ? int( substr( $jobs[0]->{jobid}, 1 ) ) : 0;

  for ( my $i = 0; $i < @jobs; $i++ )
  {
    # deserialize the target list
    $jobs[$i]->{target} = $self->{json}->decode( $jobs[$i]->{target} );
    $jobs[$i]->{target_list} = join( ',', @{$jobs[$i]->{target}} );

    # format the start time
    my $start_time = '';
    my $start_ts   = $jobs[$i]->{start_time};
    if ($start_ts)
    {
      my @t = localtime($start_ts);
      $start_time = sprintf(
        "%04d-%02d-%02dT%02d:%02d:%02d",
        $t[5] + 1900,
        $t[4] + 1,
        $t[3], $t[2], $t[1], $t[0]
      );
    }
    $jobs[$i]->{start_ts}   = $start_ts;
    $jobs[$i]->{start_time} = $start_time;

    # determine the host count
    $jobs[$i]->{host_count} = $self->_get_host_count($jobs[$i]->{jobid});
  }

  return \@jobs;
}

sub _get_host_count
{
  my ( $self, $jobid ) = @_;

  unless ( exists $HOST_COUNT_CACHE->{$jobid} )
  {
    my $resp = $self->pogo_client()->jobstatus($jobid);
    my ($jobstate, @hosts) = $resp->records;
    $HOST_COUNT_CACHE->{$jobid} = scalar @hosts;
  }

  return $HOST_COUNT_CACHE->{$jobid};
}

sub _paginate
{
  my ( $self, $data ) = @_;

  my $jobs_per_page = $data->{jobs_per_page};
  my $req_page      = $data->{req_page};
  my $num_jobs      = $data->{num_jobs};
  my %pager;

  if ( $num_jobs > $jobs_per_page )
  {
    my $last_page = int( ( $num_jobs + $jobs_per_page - 1 ) / $jobs_per_page );
    my $prev_page = max( 1,          $req_page - 1 );
    my $next_page = min( $last_page, $req_page + 1 );
    my $min_page  = max( 1,          $req_page - 5 );
    my $max_page  = min( $last_page, $min_page + 9 );
    my $offset    = 0;
    my @pages = map { { number => $_ } } ( $min_page .. $max_page );

    %pager = (
      cur       => $req_page,
      pages     => \@pages,
      prev_page => $prev_page,
      next_page => $next_page,
      last_page => $last_page
    );
  }

  return \%pager;
}

1;
