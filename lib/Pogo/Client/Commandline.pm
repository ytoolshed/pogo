package Pogo::Client::Commandline;

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

use 5.008;
use common::sense;

use Data::Dumper;

use Getopt::Long qw(:config bundling no_ignore_case pass_through);
use Crypt::OpenSSL::RSA;
use Crypt::OpenSSL::X509;
use JSON qw(encode_json);
use Log::Log4perl qw(:easy);
use Log::Log4perl::Level;
use MIME::Base64 qw(encode_base64);
use Pod::Find qw(pod_where);
use Pod::Usage qw(pod2usage);
use POSIX qw(strftime);
use Sys::Hostname qw(hostname);
use Time::HiRes qw(gettimeofday tv_interval);
use YAML::Syck qw(LoadFile DumpFile);

use Pogo::Common;
use Pogo::Client;
use Pogo::Client::AuthCheck qw(get_password check_password);
use Pogo::Client::GPGSignature qw(create_signature);

use constant POGO_GLOBAL_CONF  => $Pogo::Common::CONFIGDIR . '/client.conf';
use constant POGO_USER_CONF    => $ENV{HOME} . '/.pogoconf';
use constant POGO_WORKER_CERT  => $Pogo::Common::WORKER_CERT;
use constant POGO_SECRETS_FILE => $ENV{HOME} . '/.pogo_secrets';

my %LOG_SUBST = (
  'jobstate'  => 'job',
  'hoststate' => 'host',
);

sub run_from_commandline
{
  my $class = shift;

  my $self = {
    epoch      => [gettimeofday],
    invoked_as => quote_array( " ", $0, @ARGV ),
    userid     => scalar getpwuid($<),
  };

  bless $self, $class;

  my $cmd = $self->process_options
    or $self->cmd_usage;

  $self->{api} = delete $self->{opts}->{api};

  my $method = 'cmd_' . $cmd;
  if ( !$self->can($method) )
  {
    die "no such command: $cmd\n";
  }

  return $self->$method;
}

#{{{ cmd_run

sub cmd_run
{
  my $self = shift;
  my $opts = {
    retry       => 0,
    invoked_as  => $self->{invoked_as},
    client      => $Pogo::Client::VERSION,
    user        => $self->{userid},
    requesthost => hostname || '',
    secrets     => POGO_SECRETS_FILE,
  };
  GetOptions(
    my $cmdline_opts = {},       'cookbook|C=s',
    'hostfile|H=s',              'target|host|h=s@',
    'job_timeout|job-timeout=i', 'dryrun|n',
    'recipe|R=s',                'retry|r=i',
    'timeout|t=i',               'prehooks!',
    'posthooks!',                'hooks!',
    'secrets|S=s',               'unconstrained',
    'concurrent|cc=s',           'file|f=s',
    'keyring-dir|K=s',           'keyring-userid|U=s',
    'createsig!',                'use-password!',
    'pk-file=s',                 'sshagent!',
  );

  # --hooks will affect the default setting of both prehooks and posthooks.  If
  # the more specific option also appears, it will override the setting of
  # --hooks.
  if ( defined $cmdline_opts->{hooks} )
  {
    $opts->{prehooks} = $opts->{posthooks} = $cmdline_opts->{hooks};
  }

  # merge global options over default options
  $opts = merge_hash( $opts, $self->{opts} );

  # This is kind of weird; the commandline opts should override the recipe,
  # so we can't merge $cmdline_opts yet, but the cookbook and recipe are
  # commandline arguments themselves, so we need to check both $cmdline_opts and $opts.
  if ( $cmdline_opts->{recipe} )
  {
    my $cookbook = $self->load_cookbook( $cmdline_opts->{cookbook} || $opts->{cookbook} );
    if ( defined $cookbook )
    {
      my $recipe = $self->load_recipe( $cmdline_opts->{recipe}, $cookbook );
      $opts = merge_hash( $opts, $recipe );
    }
  }

  # merge per-cmd options over global options and cookbook options
  $opts = merge_hash( $opts, $cmdline_opts );

  $opts->{command} = $self->load_command($opts);

  die "run needs a command\n"
    unless defined $opts->{command};

  my @targets = $self->load_targets($opts);
  delete $opts->{target};
  LOGDIE "run needs hosts!\n" if ( @targets == 0 );
  $opts->{target} = \@targets;
  
  # generate a signature and add it to the job metadata
  if ( defined $opts->{createsig} && $opts->{createsig} )
  {
    my %signature = create_signature($opts);
    if ( exists $opts->{signature} ) { push( @{ $opts->{signature} }, \%signature ); }
    else { $opts->{signature} = [ \%signature ]; }
  }

  # secrets
  my $secrets;
  if ( defined $opts->{secrets} && $opts->{secrets} ne '' )
  {
    $secrets = load_secrets( $opts->{secrets} );

    if ( !$secrets )
    {
      ERROR "Can't load secrets from $opts->{secrets}: $!";
    }
  }

  # --unconstrained means we're 100% in parallel
  if ( delete $opts->{unconstrained} )
  {
    die "--unconstrained and --concurrent are mutually exclusive\n"
      if exists $opts->{concurrent};
    $opts->{concurrent} = 0;
  }

  # check the value of concurrent
  if ( exists $opts->{concurrent} )
  {
    die "--concurrent value must be an integer or a percentage\n"
      unless $opts->{concurrent} =~ m/^\d+%?$/;
  }

  if ( $opts->{dryrun} )
  {
    my $key;
    my $value;
    format DRYRUN =
^>>>>>>>>>>>>>>>>>> => ^*
$key,                  $value
.

    format_name STDOUT "DRYRUN";

    foreach $key ( sort keys %$opts )
    {
      $value = $opts->{$key};
      if ( ref $value eq 'ARRAY' )
      {
        $value = join ',', @$value;
      }
      $value = join( '; ', split /\n/, $value );
      write STDOUT;
    }

    return 0;
  }

  # bring the crypto
  Crypt::OpenSSL::RSA->import_random_seed();
  my $x509    = Crypt::OpenSSL::X509->new_from_file( $opts->{worker_cert} );
  my $rsa_pub = Crypt::OpenSSL::RSA->new_public_key( $x509->pubkey() );

  if ($opts->{sshagent})
  {
    
    if ( !defined $opts->{'pk-file'} )
    {
      my $ssh_home = $ENV{"HOME"} . "/.ssh/id_dsa";
      LOGDIE "No ssh private key file found"
        unless ( -e $ssh_home);
      $opts->{'pk-file'} = $ssh_home;
    }

    open (my $pk_fh, $opts->{'pk-file'}) or LOGDIE "Unable to open file: $!\n"; 
    my @pk_data;

    #encrypt each line of the private key since its too big as a single entity
    while (<$pk_fh>) {
      push @pk_data, encode_base64( $rsa_pub->encrypt($_));
    }
    $opts->{client_private_key} = [@pk_data];

    #Get the passphrase for the private key
    my $pvt_key_passphrase = get_password('Enter the passphrase for ' . $opts->{'pk-file'} . ': ');
    
    #if there is no passphrase, it has to be made note of
    if ($pvt_key_passphrase) {
      my $cryptphrase = encode_base64( $rsa_pub->encrypt($pvt_key_passphrase) );
      $opts->{pvt_key_passphrase} = $cryptphrase;
    }
    else 
    {
      $opts->{pvt_key_passphrase} = $pvt_key_passphrase;
    }

  }

  if ($opts->{'use-password'})
  {

    my $password = get_password();

    # use CLI::Auth to validate
    # note that this is just testing against the local password in case you happen
    # to use the same one everywhere - to avoid spewing the wrong password to
    # thousands of hosts, this is not a real auth check
    if ( $opts->{check_password} )
    {
      if ( !check_password( $self->{userid}, $password ) )
      {
        die
          "Local password check failed, bailing\nset 'check_password: 0' in your .pogoconf to disable\n";
      }
    }

    # encrypt the password 
    my $cryptpw = encode_base64( $rsa_pub->encrypt($password) );

    $opts->{password} = $cryptpw;

  }

  die "Need atleast one authentication mechanism with --password or --sshagent\n"
    unless ($opts->{sshagent} || $opts->{password});

  $opts->{user}     = $self->{userid};
  $opts->{run_as}   ||= $self->{userid};

  $opts->{secrets} = encode_base64( $rsa_pub->encrypt($secrets) );

  my $resp = $self->_client->run(%$opts);

  if ( !$resp->is_success )
  {
    die "Failed to start job: " . $resp->status_msg;
  }

  my $jobid = $resp->record;

  $SIG{INT}     = sub { $self->pogo_client()->jobhalt($jobid) if $jobid; exit 1; };
  $SIG{__DIE__} = sub { $self->pogo_client()->jobhalt($jobid) if $jobid; die @_; };

  print "$jobid; " . $self->{ui} . $jobid . "\n";

  # $self->wait_job($jobid);
  return 0;
}

#}}} cmd_run
#{{{ cmd_gensig

sub cmd_gensig
{
  my $self = shift;
  GetOptions(
    my $cmdline_opts = {}, 'recipe|R=s', 
    'cookbook|C=s',        'keyring-dir|K=s',
    'keyring-userid|U=s',  'replace-signature!', 
    'list-signatures!',
  );

  LOGDIE "recipe name is required"
    if ( !defined $cmdline_opts->{recipe} );
  LOGDIE "cookbook location is required"
    if ( !defined $cmdline_opts->{cookbook} );

  my $opts;
  my $recipe;

  foreach my $options qw(debug help)
  {
    $opts->{$options} = $self->{opts}->{$options} if defined $self->{opts}->{$options};
  }

  # load the recipe from the cookbook
  my $cookbook = $self->load_cookbook( $cmdline_opts->{cookbook} );
  if ( defined $cookbook )
  {
    $recipe = $self->load_recipe( $cmdline_opts->{recipe}, $cookbook );
    $opts = merge_hash( $opts, $recipe );
  }

  $opts = merge_hash( $opts, $cmdline_opts );

  if ( defined $cmdline_opts->{'list-signatures'} )
  {
    if ( defined $opts->{signature} )
    {
      print "Signatures: \n\n";
      for my $signature ( @{ $opts->{signature} } )
      {
        print "name      : $signature->{name} \n";
        print "signature : \n$signature->{sig} \n";
      }
    }
    else
    {
      print "The recipe does not contain any signatures \n";
    }
    return 0;
  }

  # load the command to be executed on the target
  $opts->{command} = $self->load_command($opts);

  # load the list of target nodes from
  # the hostfile or target option
  my @targets = $self->load_targets($opts);
  $opts->{target} = \@targets if (@targets != 0);

  # create the signature hash for the recipe
  my %signature = create_signature($opts);

  # append the signature to the recipe and
  # write it back to the cookbook
  foreach my $record (@$cookbook)
  {
    next if ( !defined $record );    # skip blank records
    if ( $record->{name} eq $cmdline_opts->{recipe} )
    {
      $record->{signature_fields} = $opts->{signature_fields}
        unless $record->{signature_fields};
      # if the recipe already contains some signatures
      # append the generated signature to this field
      # else create a new hash key in the recipe
      if ( ( defined $record->{signature} )
        && ( !defined $cmdline_opts->{'replace-signature'} ) )
      {
        push( @{ $record->{signature} }, \%signature );
      }
      else { $record->{signature} = [ \%signature ]; }
      last;
    }
  }

  # remove the old recipe file and
  # create a new one with the signature
  rename( $cmdline_opts->{cookbook}, $cmdline_opts->{cookbook} . ".old" );
  DumpFile( $cmdline_opts->{cookbook}, $cookbook );
  INFO("Recipe $cmdline_opts->{recipe} is appended with the signature");

  return 0;
}

#}}}
#{{{ cmd_ping

sub cmd_ping
{
  my $self = shift;
  my $res;
  my $resp = $self->_client()->ping('pong');
  my $elapsed = tv_interval( $self->{epoch}, [gettimeofday] );
  if ( !$resp->is_success )
  {
    printf "ERROR %s: %s\n", $self->{api}, $@;
    return 1;
  }

  my @foo  = $resp->records;
  my $pong = shift @foo;

  if ( !$pong )
  {
    printf "ERROR %s: no pong!\n", $self->{api};
    return 1;
  }
  if ( $pong ne 'pong' )
  {
    printf "ERROR %s: %s\n", $self->{api}, $pong;
    return 1;
  }

  printf "OK %s %0dms\n", $self->{api}, $elapsed * 1000;
  return 0;
}

#}}}
#{{{ cmd_jobs

sub cmd_jobs
{
  my $self = shift;
  my $opts = {
    user  => $self->{userid},
    limit => 50,
  };
  GetOptions( $opts, 'user|U=s', 'all', 'limit|L=i' );
  delete $opts->{user} if $opts->{all};
  delete $opts->{all}  if $opts->{all};

  DEBUG "cmd_jobs: " . encode_json($opts);

  my $resp = $self->_client()->listjobs(%$opts);
  if ( !$resp->is_success )
  {
    die "Unable to list jobs: " . $resp->status_msg;
  }

  my @matches;
  my @jobs  = $resp->records;
  my $count = 0;

JOBS: foreach my $job ( sort { $b->{jobid} cmp $a->{jobid} } @jobs )
  {
    push @matches, $job;
    $count++;
  }

  format JOB_TOP =
Job ID      User     Command
.

  my $job;
  format JOB =
@<<<<<<<<<< @<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$job->{jobid}, $job->{user}, '\''. $job->{command}. '\'',
.

  foreach $job ( sort { $a->{jobid} cmp $b->{jobid} } @matches )
  {

    if ( !defined $job->{jobid}
      || !defined $job->{user}
      || !defined $job->{command} )
    {
      DEBUG "skipping invalid job: " . $job->{'jobid'} || 'NULL';
      next;
    }

    format_name STDOUT "JOB";
    format_top_name STDOUT "JOB_TOP";
    write STDOUT;
  }
}

#}}}
#{{{ cmd_status

sub cmd_status
{
  my $self = shift;
  my $opts = {};

  # fetchez le options
  GetOptions( $opts, 'target|h=s', 'status|s=s', 'verbose|v' );

  # process the jobid
  my $jobid = shift @ARGV;
  if ( defined $jobid )
  {
    $jobid = $self->to_jobid($jobid);
    if ( !defined $jobid )
    {
      die "No jobs found";
    }
    DEBUG "Using jobid '$jobid'";
  }
  else
  {
    die "no jobid specified";
  }

  # expand the targets if needed
  my $target;
  if ( defined $opts->{target} )
  {
    $target = $self->expand_expression( $opts->{target} );
  }

  # fetch the job info
  my $resp = $self->_client()->jobinfo( $jobid, %$opts );
  if ( !$resp->is_success )
  {
    die "Unable to fetch jobinfo: " . $resp->status_msg;
  }

  # output job info
  my $info = $resp->record;
  my $disp = {
    'job id'     => $jobid,
    'user'       => $info->{user},
    'command'    => $info->{command},
    'invoked as' => $info->{invoked_as},
  };

  if ( $opts->{verbose} ) { $disp = $info; }

  my $len = 5;
  map { $len = length($_) if $len < length($_) } keys %{$disp};

  my $pat = " %${len}s: %s\n";

  foreach my $key ( keys %{$disp} )
  {
    printf "$pat", $key, $disp->{$key};
  }

  # fetch the status
  $resp = $self->_client()->jobstatus($jobid);
  if ( !$resp->is_success )
  {
    die "Unable to fetch jobstatus: " . $resp->status_msg;
  }

  # output status
  my @records = $resp->records;
  my $status  = shift @records;
  printf "$pat", "job status", $status;
  while ( my $rec = shift @records )
  {
    my ( $host, $status, $exit ) = @$rec;
    if ( !defined $target || $target->contains($host) )
    {
      if ( !exists $opts->{status} || $opts->{status} eq $status )
      {
        print "  $host => $status\n";
      }
    }
  }

  return 0;
}

#}}}
#{{{ cmd_log

sub cmd_log
{
  my $self = shift;
  my $opts = { verbose => 0 };

  GetOptions( $opts, 'tail|f', 'verbose|v' )
    or $self->usage;

  my $jobid = shift @ARGV;
  $opts = merge_hash( $self->{opts}, $opts );

  if ( defined $jobid )
  {
    $jobid = $self->to_jobid($jobid);
    if ( !defined $jobid )
    {
      print "No jobs found\n";
      return 1;
    }
    DEBUG "Using jobid '$jobid'";
  }
  unless ($jobid)
  {
    die "no jobid specified\n";
  }

  my $hosts;
  my $target = shift @ARGV;

  if ( defined $target )
  {
    $hosts = $self->expand_expression($target);
  }

  my $idx      = 0;
  my $limit    = 100;
  my $finished = 0;
  my $resp;

  do
  {
    $resp = $self->_client->joblog( $jobid, $idx, $limit );
    if ( !$resp->is_success )
    {
      ERROR "%s: %s\n", $self->{api}, $resp->status_msg;
      return -1;
    }

    my @records = $resp->records;

    foreach my $record ( sort { $a->[0] <=> $b->[0] } @records )
    {
      $idx = ( shift @$record ) + 1;
      display_log_event( $jobid, $record, $opts->{verbose}, $hosts );
      if ( $record->[1] eq 'jobstate' )
      {
        my $newstate = $record->[2]->{state};
        $finished = 1 if ( $newstate eq 'finished' or $newstate eq 'halted' );
      }
    }
  } while ( scalar $resp->records == $limit );

  if ( $opts->{tail} )
  {
    while ( !$finished )
    {
      $resp = $self->_client->joblog( $jobid, $idx, $limit );
      if ( !$resp->is_success )
      {
        ERROR "ERROR: %s: %s\n", $self->api, $resp->status_msg;
      }

      my $laststate;
      my $lastthing;

      foreach my $record ( sort { $a->[0] <=> $b->[0] } $resp->records )
      {
        $idx = ( shift @$record ) + 1;
        display_log_event( $jobid, $record, $opts->{verbose}, $hosts );
        if ( $record->[1] eq 'jobstate' )
        {
          my $newstate = $record->[2]->{state};
          $finished = 1 if ( $newstate eq 'finished' or $newstate eq 'halted' );
        }
      }

      sleep 0.6 unless scalar $resp->records == $limit;
    }
  }

  return 0;
}

sub display_log_event
{
  my ( $jobid, $event, $verbose, $hosts )   = @_;
  my ( $ts,    $type,  $details, $summary ) = @$event;

  $ts = to_ts($ts);

  # cosmetic crap
  if ( defined $LOG_SUBST{$type} )
  {
    $type = $LOG_SUBST{$type};
  }

  my $ok = 1;
  if ( defined $hosts && $type eq 'host' && ref $details eq 'HASH' )
  {
    $ok = $hosts->has( $details->{host} );
  }

  if ( ref $details eq 'HASH' )
  {
    if ( defined $details->{host} )
    {
      $type = "$type/" . $details->{host};
    }
  }
  else
  {
    $type = $details;
  }

  my ( $keys, $values );
  format JOBLOG =
@<<<<<<<<<<<<<<<<<<<<<<< @* => @*
$ts,                     $type, $summary
.

  format JOBLOG_VERBOSE =
@<<<<<<<<<<<<<<<<<<<<<<< @* => @*
$ts,                     $type, $summary
                         ^* => ^*
~~                       $keys, $values
.

  if ($ok)
  {
    if ($verbose)
    {
      format_name STDOUT 'JOBLOG_VERBOSE';
      $keys   = join "\n", keys %$details;
      $values = join "\n", values %$details;
      write;
    }
    else
    {
      format_name STDOUT 'JOBLOG';
      write;
    }
  }
}

sub to_ts
{
  my $ts = shift;
  my ( $secs, $msecs ) = split /\./, $ts;
  $ts = strftime '%b %e %H:%M:%S UTC%z', localtime($secs);
  return $ts;
}

#}}}
#{{{ options processing and usage

sub process_options
{
  my $self = shift;

  my $command;
  my $opts = { worker_cert => POGO_WORKER_CERT, };
  my $cmdline_opts = {};

  # first, process global options and see if we have an alt config file
  GetOptions( $cmdline_opts, 'help|?', 'api=s', 'configfile|c=s', 'debug', 'namespace|ns=s',
    'worker_cert=s' );

  Log::Log4perl::get_logger->level($DEBUG)
    if $cmdline_opts->{debug};

  $self->cmd_usage
    if $cmdline_opts->{help};

  # our next @ARGV should be our command
  $command = shift @ARGV || return;
  if ( $command =~ m/^-/ )
  {
    ERROR "Unknown option: $command";
    return;
  }

  # load global config
  $opts->{configfile} ||= $cmdline_opts->{configfile};
  $opts->{configfile} ||= POGO_GLOBAL_CONF;

  my $globalconf = {};

  if ( -r $opts->{configfile} )
  {
    DEBUG "Loading configfile '" . $opts->{configfile} . "'";
    eval { $globalconf = LoadFile( $opts->{configfile} ); };
    if ($@)
    {
      ERROR "Could't load config '" . $opts->{configfile} . "': $@";
      return;
    }

    # opts start with configfile
    $opts = $globalconf;
  }
  else
  {
    WARN "Couldn't open config '" . $opts->{configfile} . "'";
  }

  # overwrite with user conf
  my $userconf = {};
  if ( -r POGO_USER_CONF )
  {
    DEBUG "Loading configfile '" . POGO_USER_CONF . "'";
    eval { $userconf = LoadFile(POGO_USER_CONF); };
    if ($@)
    {
      WARN "Couldn't load config '" . POGO_USER_CONF . "': $@";
    }
    if ($userconf)
    {
      $opts = merge_hash( $opts, $userconf );
      $opts->{configfile} = POGO_USER_CONF;
    }
  }

  # overwrite with commandline opts
  $self->{opts} = merge_hash( $opts, $cmdline_opts );

  return $command;
}

sub cmd_help
{
  return $_[0]->cmd_man;
}

sub cmd_man
{
  return pod2usage(
    -verbose => 2,
    -exitval => 0,
    -input   => pod_where( { -inc => 1, }, __PACKAGE__ ),
  );
}

sub cmd_usage
{
  my $self = shift;
  return pod2usage(
    -verbose  => 99,
    -exitval  => shift || 1,
    -input    => pod_where( { -inc => 1 }, __PACKAGE__ ),
    -sections => 'USAGE|MORE INFO',
  );
}

#}}} options processing and usage
#{{{ helper crap

# this is a bit of a mystery to me
sub quote_array
{
  my ( $sep, @array ) = @_;
  foreach my $elem (@array)
  {
    if ( $elem !~ m/^[a-z0-9+_\.\/-]+$/i )
    {
      $elem = "'$elem'";
    }
  }
  my $str .= join( $sep, @array );
  $str .= $sep;
  return $str;
}

sub merge_hash
{
  my ( $onto, $from ) = @_;

  while ( my ( $key, $value ) = each %$from )
  {
    if ( defined $onto->{$key} )
    {
      DEBUG sprintf "Overwriting key '%s' with '%s', was '%s'", $key, $value, $onto->{$key};
    }
    $onto->{$key} = $value;
  }

  return $onto;
}

sub _client
{
  my $self = shift;
  if ( !defined $self->{pogoclient} )
  {
    $self->{pogoclient} = Pogo::Client->new( $self->{api} );
    Log::Log4perl->get_logger("Pogo::Client")->level($DEBUG) if ( $self->{opts}->{debug} );
  }

  return $self->{pogoclient};
}

sub load_secrets
{
  my $file = shift;
  if ( -r $file )
  {
    my $data = load_yaml($file)
      or ERROR "Couldn't load data from '$file': $!" and return;
    if ( defined $data )
    {
      return $data;
    }
  }
  else
  {
    INFO "Can't load data from '$file': $!";
    return;
  }

  return;
}

# we're just always going to have to do this server-side for now
sub expand_expression
{
  my ( $self, @foo ) = @_;

  my @hosts;
  foreach my $exp (@foo)
  {
    DEBUG "expanding $exp";

    my $resp;
    eval { $resp = $self->_client()->expand( \@foo ); };
    if ( $@ || !$resp->is_success )
    {
      die "unable to expand '$exp': " . $@ || $resp->status_msg;
    }
    push( @hosts, @{ $resp->records } );
  }

  return Set::Scalar->new(@hosts);
}

sub to_jobid
{
  my ( $self, $jobid ) = @_;

  my $p = 'p';
  my $i;

  if ( $jobid eq 'last' )
  {
    $jobid = $self->get_last_jobid( $self->{userid} );
  }

  if ( $jobid =~ m/^([a-z]+)(\d+)$/ )
  {
    ( $p, $i ) = ( $1, $2 );
  }
  elsif ( $jobid =~ m/^(\d+)$/ )
  {
    $i = $1;
  }
  else
  {
    ERROR "Don't understand jobid '$jobid'";
    return;
  }

  my $new_jobid;
  if ( defined $i )
  {
    $new_jobid = sprintf "%s%010d", $p, $i;
    DEBUG "Translated jobid '$jobid' to '$new_jobid'";
  }
  else
  {
    INFO "No jobs found";
  }

  return $new_jobid;
}

sub load_command
{
  my ( $self, $opts ) = @_;
  
  if ( @ARGV > 0 )
  {
    $opts->{command} = "@ARGV";
  }
  elsif ( $opts->{cmd} )
  {
    $opts->{command} = delete $opts->{cmd};
  }

  # run an anonymous executable?
  if ( defined $opts->{file} )
  {
    die "file \"" . $opts->{file} . "\" does not exist\n" unless -e $opts->{file};
    die "unable to read \"" . $opts->{file} . "\"\n"      unless -r $opts->{file};

    $opts->{exe_name} = ( split( /\//, $opts->{file} ) )[-1];
    $opts->{exe_data} = encode_base64( read_file( $opts->{file} ) );
    $opts->{command}  = "Attached file: " . $opts->{exe_name};
  }

  return $opts->{command};
}

sub load_targets
{
  my ( $self, $opts ) = @_;
  my @targets;
  
  if ( exists $opts->{target} )
  {
    push @targets, @{ delete $opts->{target} };
  }

  if ( $opts->{hostfile} )
  {
    foreach my $hostfile ( @{ $opts->{hostfile} } )
    {
      if ( -r $hostfile )
      {
        open( my $fh, '<', $hostfile )
          or die "Couldn't open file: $!";

        while ( my $host = <$fh> )
        {
          next unless $host;
          next if $host =~ m/^\s*#/;
          chomp($host);
          push @targets, $host;
        }
        close($fh);
      }
      else
      {
        die "couldn't read '$hostfile'";
      }
    }
  }

  return @targets;
}

sub load_cookbook
{
  my ( $self, $cookbook ) = @_;
  DEBUG "Loading cookbook '$cookbook'";

  if ( !$cookbook )
  {
    ERROR "No cookbook from which to load recipe";
    return;
  }

  # load cookbook
  my $data = load_yaml( $cookbook, $self->{opts}->{configfile} );

  if ( ref($data) ne 'ARRAY' )
  {
    ERROR "$cookbook is not a properly formatted YAML array; see documentation\n";
    return;
  }

  return $data;
}

sub load_recipe
{
  my ( $self, $recipe_name, $cookbook ) = @_;

  DEBUG "Loading recipe '$recipe_name'";

  my @results;
  foreach my $record (@$cookbook)
  {
    next if ( !defined $record );    # skip blank records
    if ( $record->{name} eq $recipe_name )
    {
      push @results, $record;
    }
  }

  if ( @results > 1 )
  {
    WARN "Multiple recipes found for '$recipe_name', using first";
  }

  my $recipe = $results[0];

  if ( !defined $recipe )
  {
    ERROR "Recipe '$recipe_name' not found in cookbook";
    return;
  }

  if ( $recipe->{based_on} )
  {
    my $based_on = $self->load_recipe( $recipe->{based_on}, $cookbook );
    if ( !defined $based_on )
    {
      ERROR
        "'$recipe_name' is based on '$recipe->{based_on}', which does not exist in the cookbook";
      return;
    }
    $recipe = merge_hash( $based_on, $recipe );
  }

  return $recipe;
}

sub load_yaml
{
  my $uri = uri_to_absuri(@_);

  my $r;
  eval { $r = $Pogo::Common::USERAGENT->get($uri); };
  if ($@)
  {
    LOGDIE "Couldn't fetch uri '$uri': $@\n";
  }

  my $yaml;
  if ( $r->is_success )
  {
    $yaml = $r->content;
  }
  else
  {
    LOGDIE "Couldn't fetch uri '$uri': " . $r->status_line . "\n";
  }

  my @data;
  eval { @data = YAML::XS::Load($yaml); };
  if ($@)
  {
    LOGDIE "couldn't parse '$uri': $@\n";
  }

  DEBUG sprintf "Loaded %s records from '$uri'", scalar @data;

  if ( scalar @data == 1 )
  {
    return $data[0];
  }

  return \@data;
}

sub uri_to_absuri
{
  DEBUG Dumper \@_;
  my $rel_uri = shift;
  my $base_uri = shift;

  $base_uri = URI->new($base_uri);

  if ( !$base_uri->scheme )
  {
    $base_uri = URI::file->new_abs($base_uri);
  }
  my $abs_uri = URI->new_abs( $rel_uri, $base_uri );

  if ( !$abs_uri->scheme )
  {
    $abs_uri = URI::file->new_abs($abs_uri);
  }

  if ( $abs_uri ne $rel_uri )
  {
    DEBUG "converted '$rel_uri' to '$abs_uri'";
  }

  return $abs_uri->as_string;
}

#}}} helper crap

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
  Michael Fischer <michael+pogo@dynamine.net>
  Mike Schilli <m@perlmeister.com>
  Nicholas Harteau <nrh@hep.cat>
  Nick Purvis <nep@noisetu.be>
  Robert Phan <robert.phan@gmail.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
