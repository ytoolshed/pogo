package Pogo::Client::Commandline;

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

use common::sense;

use Getopt::Long qw(:config bundling no_ignore_case pass_through);
use Log::Log4perl qw(:easy);
use Log::Log4perl::Level;
use Pod::Find qw(pod_where);
use Pod::Usage qw(pod2usage);
use Sys::Hostname qw(hostname);
use Time::HiRes qw(gettimeofday);
use YAML::XS qw(LoadFile);

use Pogo::Common;

use constant POGO_GLOBAL_CONF => $Pogo::Common::CONFIGDIR . '/client.conf';
use constant POGO_USER_CONF   => $ENV{HOME} . '/.pogoconf';

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

  my $method = 'cmd_' . $cmd;
  if ( !$self->can($method) )
  {
    LOGDIE "no such command: $cmd\n";
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
  };
  GetOptions(
    my $cmdline_opts = {}, 'cookbook|C=s',
    'hostfile|H=s',              'target|host|h=s',
    'job_timeout|job-timeout=i', 'dryrun|n',
    'recipe|R=s',                'retry|r=i',
    'timeout|t=i',               'prehooks!',
    'posthooks!',                'hooks!',
    'passfile|P=s',              'unconstrained',
    'concurrent|cc=s',           'file|f=s',
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
    LOGDIE "file \"" . $opts->{file} . "\" does not exist\n" unless -e $opts->{file};
    LOGDIE "unable to read \"" . $opts->{file} . "\"\n"      unless -r $opts->{file};

    $opts->{exe_name} = ( split( /\//, $opts->{file} ) )[-1];
    $opts->{exe_data} = encode_base64( read_file( $opts->{file} ) );
    $opts->{command}  = "Attached file: " . $opts->{exe_name};
  }

  LOGDIE "run needs a command\n"
    unless defined $opts->{command};

  my @targets;
}

#}}} cmd_run
#{{{ options processing and usage

sub process_options
{
  my $self = shift;

  my $command;
  my $opts         = {};
  my $cmdline_opts = {};

  # first, process global options and see if we have an alt config file
  GetOptions( $cmdline_opts, 'help|?', 'api=s', 'configfile=s', 'debug', 'namespac|ns=s', );

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
  my $opts->{configfile} = $cmdline_opts->{configfile} || POGO_GLOBAL_CONF;

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

  Andrew Sloane <asloane@yahoo-inc.com>
  Michael Fischer <mfischer@yahoo-inc.com>
  Nicholas Harteau <nrh@yahoo-inc.com>
  Nick Purvis <nep@yahoo-inc.com>
  Robert Phan <rphan@yahoo-inc.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
