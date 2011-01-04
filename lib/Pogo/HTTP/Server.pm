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
use CGI ();
use Carp;
use Fcntl qw(SEEK_SET);
use HTTP::Date qw(str2time);
use JSON::XS;
use Log::Log4perl qw(:easy);
use MIME::Types qw(by_suffix);
use POSIX qw(strftime);
use Template;

my $instance;
my $HOST_COUNT_CACHE = {};
our %RESPONSE_MSGS = (
  200 => 'OK',
  206 => 'PARTIAL CONTENT',
  304 => 'NOT MODIFIED',
  404 => 'NOT FOUND',
  500 => 'ERROR'
);

# ::Server - pogo's built-in http server
# 1. dispatch api requests at /api/vX (currently always 3)
#    api requests are currently syncronous, we should probably pass a callback along
#    this is made difficult by many of the methods taking variable arguments.
#
# 2. serve static content from /static
#
# 3. respond to UI requests - any other url is handled by the UI handler
#    Template.pm is used to generate a job index at /, and /p\d+ or /\d+ urls are
#    interpreted as jobids
#
# handle_* subs need $httpd and $request and are expected
# to $request->respond() and $httpd->stop_request()
# ui_(*) are subs for requests to /$1

# {{{ constructors

sub run
{
  Carp::croak "Server already running" if $instance;
  my $class = shift;
  $instance = {@_};
  bless $instance, $class;

  if ( !defined $instance->{http_port} )
  {
    INFO "'http_port' not defined, not serving http";
    return;
  }

  $instance->{httpd} = AnyEvent::HTTPD->new(
    host            => $instance->{bind_address},
    port            => $instance->{http_port},
    request_timeout => 10,
  );

  # note that due to the way that AnyEvent::HTTPD works, any handlers must
  # call $httpd->stop_request, or events will be generated for all handlers that match
  # the request

  if ( defined $instance->{static_path} )
  {
    $instance->{httpd}->reg_cb(
      '/favicon.ico' => sub { handle_favicon(@_); },    # just a hack to 301 /favicon to /static
      '/static'      => sub { handle_static(@_); },
    );
  }
  else
  {
    INFO "'static_path' not defined, not serving static content";
  }

  if ( defined $instance->{serve_api} && $instance->{serve_api} )
  {
    $instance->{httpd}->reg_cb( '/api' => sub { handle_api(@_) }, );
  }
  else
  {
    INFO "'serve_api' not defined, not serving api requests";
  }

  if ( defined $instance->{template_path} )
  {
    $instance->{httpd}->reg_cb( '' => sub { handle_ui(@_) }, );
    $instance->{tt} ||= Template->new( { INCLUDE_PATH => $instance->{template_path}, DEBUG => 1 } );
  }
  else
  {
    INFO "'template_path' not defined, not serving ui requests";

    $instance->{httpd}->reg_cb(
      '' => sub {
        $_[1]->respond(
          [ 404,
            'NOT FOUND',
            { 'Content-type' => 'text/html' },
            '<html><head><title>404 not found</title></head><body><h2>404 not found</h2></body></html>'
          ]
        );
        $_[0]->stop_request();
      }
    );
  }

  INFO sprintf(
    "Accepting HTTP requests on %s:%s",
    $instance->{httpd}->host,
    $instance->{httpd}->port
  );
}

# }}}
# {{{ handle_api

sub handle_api
{
  my ( $httpd, $request ) = @_;
  INFO sprintf( 'Received HTTP request for %s from %s:%d',
    $request->url, $request->client_host, $request->client_port );

  # Set these to some defaults in case an exception is raised.
  my $response         = Pogo::Engine::Response->new;
  my $response_format  = $request->parm('format') || 'json-pretty';
  my $response_headers = {
      'Content-Type' => $response_format eq 'yaml'
    ? 'text/plain'
    : 'text/javascript'
  };

  # we eval this whole block as a request to handle; any die()'s within the
  # block are properly logged/responded to below
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
      if ( $request->parm('r') )
      {
        die "c/v mutually exclusive"
          if $request->parm('c') && $request->parm('v');

        my $req = JSON::XS::decode_json( $request->parm('r') );
        my ( $action, @args ) = @$req;

        # TODO: pass callback
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
  $httpd->stop_request();
}

# }}}
# {{{ handle_static

# static content is served from 'static_path' in the dispatcher.conf
# we try to be reasonably careful here about not serving random files
sub handle_static
{
  my ( $httpd, $request ) = @_;
  INFO sprintf( 'Received HTTP request for %s from %s:%d',
    $request->url, $request->client_host, $request->client_port );

  my $response_headers = { 'Content-type' => 'application/octet-stream', };

  if ( !defined $instance->{static_path}
    || !-d $instance->{static_path}
    || !-r $instance->{static_path} )
  {
    ERROR "no static path?";
    return handle_ui_error( $httpd, $request, "not found" );
  }

  if ( $request->url =~ m{\.\.} )
  {
    ERROR "suspicious url: " . $request->url;
    return handle_ui_error( $httpd, $request, "foo" );
  }

  my $path = $request->url;
  $path =~ s/^\/static//;

  my $filepath = $instance->{static_path} . $path;

  if ( !-f $filepath || !-r $filepath )
  {
    return handle_ui_error( $httpd, $request, $request->url . " not found" );
  }

  my $headers = $request->headers;
  my $size    = -s $filepath;

  # first check for an if-modified-since header
  if (exists $headers->{'if-modified-since'} && (my $tmp = str2time($headers->{'if-modified-since'})))
  {
    $request->respond(
      [ 304, $RESPONSE_MSGS{304}, {}, undef ]
    ) if $tmp > (stat($filepath))[9];
  }

  # we want to limit the size of the response, whether the request is for the
  # full file or a byte range within the file, so for files that exceed the
  # max size, we can still request byte ranges within it
  my ($start, $end, $len) = (0, undef, $size);
  if (exists $headers->{range} && $headers->{range} =~ m/bytes=(\d+)-(\d+)$/i)
  {
    ($start, $end) = ($1, $2);
    $len = ($end - $start > -1) ? ($end - $start) + 1 : 0;
  }

  if ( $len > 102400 )
  {
    return handle_ui_error( $httpd, $request, "too big" );
  }

  $response_headers->{'Content-length'} = $size;
  $response_headers->{'Content-type'}   = (by_suffix($filepath))[0];

  if (defined $end)
  {
    open my $fh, '<', $filepath
      or confess "couldn't open file";
    seek $fh, $start, SEEK_SET if $start;
    sysread $fh, my $buffer, $len;
    $response_headers->{'Content-Range'}  = sprintf "bytes %d-%d/%d", $start, $end, $size;
    $response_headers->{'Content-length'} = $len;
    $request->respond(
      [ 206, $RESPONSE_MSGS{206}, $response_headers, $buffer ]
    );
    close $fh
      or confess "couldn't close file";
  }
  else
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

  $httpd->stop_request();
}

# }}}
# {{{ handle_favicon

# quick hack for redirecting favicon requests
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
  $httpd->stop_request();
}

# }}}
# {{{ handle_async

# handle_async should eventually supplant handle_api
# essentially it's a copy that supports callbacks
sub handle_async
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
  $httpd->stop_request();
}

# }}}
# {{{ handle_ui

sub handle_ui
{
  my ( $httpd, $request ) = @_;
  my $response_headers = { 'Content-type: text/html', };

  INFO sprintf( 'Received HTTP request for %s from %s:%d',
    $request->url, $request->client_host, $request->client_port );

  # extract our command or jobid from url, falling back to index.
  my ( undef, $method, @args ) = split( '/', $request->url );

  my $ocmd = ( split( m{/}, $method ) )[-1] || 'index';
  my $cmd = "ui_${ocmd}";
  my @args;

  # if the requested method isn't valid, see if it's a jobid instead
  eval {
    if ( !$instance->can($cmd) )
    {
      my $jobid = to_jobid($ocmd);

      # perhaps we should redirect to the correct jobid url here
      # if to_jobid() modifies the jobid
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
    ERROR sprintf( "encountered an error with '%s': %s", $request->url, $@ );
    handle_ui_error( $httpd, $request, $@ ) if $@;
  }
  $httpd->stop_request();
}

# }}}
# {{{ handle_ui_error

# any ui errors
sub handle_ui_error
{
  my ( $httpd, $request, $error ) = @_;
  $instance->{tt}->process(
    'error.tt',
    { error => $error, page_title => 'ERROR', },
    sub {
      my $output = shift;
      $request->respond( [ 500, 'ERROR', { 'Content-type' => 'text/html' }, $output ] );
    },
    )
    or $request->respond(
    [ 500, 'ERROR',
      { 'Content-type' => 'text/plain' },
      "an unknown error occurred: " . $instance->{tt}->error
    ]
    );
  $httpd->stop_request();
}

# }}}

# render the requested template, adding any global config data to the template
# data
sub _render_ui_template
{
  my ( $self, $request, $template, $data, $resp_code, $content_type ) = @_;

  $resp_code    ||= 200;
  $content_type ||= 'text/html';

  # add ui config items, stripping the "ui_" portion of the name
  map { $data->{substr($_, 3)} ||= $self->{$_} } grep { /^ui_/ } keys %$self;
  # this guy will be interpolated unless it's already been defined
  $data->{pogo_api} ||= sprintf( 'http://%s:%s/api/v3', $instance->{httpd}->host, $instance->{httpd}->port );

  $instance->{tt}->process(
    $template,
    $data,
    sub {
      my $output = shift;
      $request->respond(
        [
          $resp_code, 
          $RESPONSE_MSGS{$resp_code},
          { 'Content-type' => $content_type },
          $output
        ]
      )
    }
  ) or die $instance->{tt}->error, "\n";
}

# {{{ ui_status

# individual job status, needs a jobid
sub ui_status
{
  my ( $self, $request, $jobid ) = @_;

  $jobid =~ m{^[a-z]\d+$}i || die "bad jobid $jobid\n";
  my $resp = Pogo::Engine->jobinfo($jobid);
  if ( !$resp->is_success )
  {
    die "Couldn't fetch jobinfo for $jobid: " . $resp->status_msg . "\n";
  }

  my $data = {
    page_title  => 'job status: ' . $jobid,
    jobid       => $jobid,
    jobinfo     => $resp->record
  };

  $self->_render_ui_template(
    $request,
    'status.tt',
    $data
  );
}

# }}}
# {{{ ui_index

# the main job index, paginated
sub ui_index
{
  my ( $self, $request, @args ) = @_;

  my $jobs_per_page = $request->parm('max') || 25;

  # initialize filters
  my %filters;
  foreach my $f (qw(user state target))
  {
    my $value = $request->parm($f);
    $filters{$f} = $value if defined $value;
  }

  # calculate the offset
  my $req_page = $request->parm('cur') || 1;
  my $offset = ( $req_page - 1 ) * $jobs_per_page;
  $filters{offset} = $offset if $offset;

  # determine the total number of jobs
  my $max_jobid = _list_jobs( offset => 0, limit => 2 )->[0]->{jobid};
  my $num_jobs = $jobs_per_page;
  if ( $max_jobid =~ m/^p(\d+)$/ )
  {
    $num_jobs = int($1) - $instance->{jobid_offset};
  }

  # build our data
  my $data = {
    page_title    => 'job index',
    jobs          => _list_jobs( page => $req_page, limit => $jobs_per_page, %filters ),
    running_jobs  => _list_jobs( state => 'running' ),
    jobs_per_page => $jobs_per_page,
    num_jobs      => $num_jobs,
    req_page      => $req_page,
    %filters
  };

  $data->{pager} = _paginate($data);

  $self->_render_ui_template(
    $request,
    'index.tt',
    $data
  );
}

sub _list_jobs
{
  my (%filters) = @_;

  my $req_page = delete $filters{page} || 1;

  my $resp = Pogo::Engine->listjobs(%filters);

  # reformat the output
  my @jobs = $resp->records;
  my $num_jobs = @jobs > 0 ? int( substr( $jobs[0]->{jobid}, 1 ) ) : 0;

  for ( my $i = 0; $i < @jobs; $i++ )
  {

    # deserialize the target list
    $jobs[$i]->{target} = JSON::XS::decode_json( $jobs[$i]->{target} );
    $jobs[$i]->{target_list} = join( ',', @{ $jobs[$i]->{target} } );

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
    $jobs[$i]->{host_count} = _get_host_count( $jobs[$i]->{jobid} );
  }

  return \@jobs;
}

sub _get_host_count
{
  my ($jobid) = @_;

  unless ( exists $HOST_COUNT_CACHE->{$jobid} )
  {
    my $resp = Pogo::Engine->jobstatus($jobid);
    my ( $jobstate, @hosts ) = $resp->records;
    $HOST_COUNT_CACHE->{$jobid} = scalar @hosts;
  }

  return $HOST_COUNT_CACHE->{$jobid};
}

sub _paginate
{
  my ($data) = @_;

  my $jobs_per_page = $data->{jobs_per_page};
  my $req_page      = $data->{req_page};
  my $num_jobs      = $data->{num_jobs};
  my %pager;

  if ( $num_jobs > $jobs_per_page )
  {
    my $last_page = int( ( $num_jobs + $jobs_per_page - 1 ) / $jobs_per_page );
    my $prev_page = max( 1, $req_page - 1 );
    my $next_page = min( $last_page, $req_page + 1 );
    my $min_page = max( 1, $req_page - 5 );
    my $max_page = min( $last_page, $min_page + 9 );
    my $offset   = 0;
    my @pages    = map { { number => $_ } } ( $min_page .. $max_page );

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

# }}}
# {{{ ui_output

sub ui_output
{
  my ( $self, $request, @args ) = @_;

  my $pogo_id  = $request->parm('pogoid') || die "No pogo job ID provided\n";
  my $hostname = $request->parm('host')   || die "No host provided\n";

  # grab the job info
  my $resp = Pogo::Engine->jobinfo($pogo_id);
  die "couldn't fetch jobinfo: " . $resp->status_msg if ( !$resp->is_success );
  my $jobinfo = ( $resp->records )[0];

  $resp = Pogo::Engine->jobhoststatus( $pogo_id, $hostname );
  die "couldn't fetch host status: " . $resp->status_msg if ( !$resp->is_success );
  my $hostinfo = {
    hostname   => $hostname,
    state      => ( $resp->records )[0],
    host_state => sprintf( "%s: %s", $resp->records )
  };

  $resp = Pogo::Engine->hostlog_url( $pogo_id, $hostname );
  die "couldn't fetch host status: " . $resp->status_msg if ( !$resp->is_success );
  my $urls = $resp->record;
  shift @$urls;    # toss hostname;

  # output
  # TODO: this needs to move into js in the browser

  my @output;
  my $ua  = LWP::UserAgent->new();
  my $n   = 0;
  my $run = 0;                       # run #
  my $ran = 0;                       # whether or not we've appended the run to our output
  foreach my $url (@$urls)
  {
    DEBUG "working on $url";
    my $resp = $ua->get($url);
    unless ( $resp->is_success )
    {
      die "Unable to get " . $hostinfo->{'output'} . ": " . $resp->status_line . "\n";
    }
    foreach my $entry ( split( /\r?\n/, $resp->decoded_content ) )
    {
      my $json = JSON::XS::decode_json($entry);
      my ( $info, $lines ) = @$json;

      foreach my $line ( split( /\r?\n/, $lines ) )
      {
        if ( $info->{type} eq 'EXIT' )
        {
          if ( $line eq "0" )
          {
            $info->{type} = 'EXIT0';
          }
          $line = "Exited with status $line";
        }
        my $rec = {
          number => ++$n,
          time   => strftime( "%H:%M:%S", localtime int $info->{ts} ) . "."
            . sprintf( "%03d", 1000 * ( $info->{ts} - int $info->{ts} ) ),
          type  => $info->{type},
          line  => CGI::escapeHTML($line),
          class => ( $run % 2 == 0 ) ? 'timestamp' : 'stamptime'
        };
        unless ($ran)
        {
          $ran++;
          $rec->{run} = $run + 1;
        }
        push( @output, $rec );
      }
    }
    $run++;
    $ran = 0;
  }

  my $data = {
    page_title => sprintf( "Pogo UI: %s: %s", $pogo_id, $hostname ),
    pogo_id    => $pogo_id,
    jobinfo    => $jobinfo,
    hostinfo   => $hostinfo,
    output     => \@output
  };

  $self->_render_ui_template(
    $request,
    'output.tt',
    $data
  );
}

# }}}
# {{{ misc

# simple helper function to convert user-supplied string to a jobid.
# TODO: move to Pogo::Common?  I think this is duplicated in the
# client.
sub to_jobid
{
  my ($jobid) = @_;

  my $p = 'p';
  my $i;

  if ( $jobid eq 'last' )
  {
    ();    # TODO: how do we determine user?
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
    die "jobid not found\n";
  }

  return $new_jobid;
}

# }}}

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
