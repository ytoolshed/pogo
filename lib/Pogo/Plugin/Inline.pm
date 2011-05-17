package Pogo::Plugin::Inline;

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

use common::sense;

use Data::Dumper;
use Log::Log4perl qw(:easy);
use String::Glob::Permute qw(string_glob_permute);

sub new
{
  my ( $class, %opts ) = @_;
  return bless \%opts, $class;
}

# {{{ expand_targets
sub expand_targets
{
  my ( $self, $targets ) = @_;
  my @flat;
  foreach my $target (@$targets)
  {
    push @flat, string_glob_permute($target);
  }

  my %uniq = ();
  @flat = grep { !$uniq{$_}++ } @flat;
  return \@flat;
}

# }}}
# {{{ fetch_target_meta

sub fetch_target_meta
{
  my ( $self, $targets, $nsname, $errc, $cont, $logcont, $opts ) = @_;
  my $hinfo = {};
  $opts = {} unless defined $opts;

  my $cache_key = "default";
  $cache_key = $opts->{cache_key} if defined $opts->{ cache_key };

  if ( !defined $self->{_target_cache}->{$cache_key} )
  {
    DEBUG "Start updating Inline meta cache (cache key $cache_key)";

    # populate the cache anew - we might as well do it for all hosts
    my $conf = $self->{conf}->();

    foreach my $app ( sort keys %{ $conf->{apps} } )
    {
      foreach my $expression ( @{ $conf->{apps}->{$app} } )
      {
        foreach my $host ( string_glob_permute( $expression ) )
        {
          DEBUG "{$host}->{apps}->{$app}";
          $hinfo->{$host}->{apps}->{$app} = 1;
        }
      }
    }

    foreach my $envtype ( sort keys %{ $conf->{envs} } )
    {
      foreach my $envname ( sort keys %{ $conf->{envs}->{$envtype} } )
      {
        foreach my $expression ( @{ $conf->{envs}->{$envtype}->{$envname} } )
        {
          foreach
            my $host ( string_glob_permute( $expression ) )
          {
            DEBUG "{$host}->{envs}->{$envtype}->{$envname}";
            $hinfo->{$host}->{envs}->{$envtype}->{$envname} = 1;
          }
        }
      }
    }

    foreach my $target ( keys %$hinfo )
    {
      $self->{_target_cache}->{$cache_key}->{$target}->{apps} = 
         [ keys %{ $hinfo->{$target}->{apps} } ];

      foreach my $envtype ( keys %{ $hinfo->{$target}->{envs} } )
      {
        $self->{_target_cache}->{$cache_key}->{$target}->{envs}->{$envtype} =
          $hinfo->{$target}->{envs}->{$envtype};
      }
    }
  }

  DEBUG "End updating Inline meta cache (cache_key=$cache_key)";

    # Only pass on data for the data we asked for
  $cont->( { map { $_ => $self->{_target_cache}->{$cache_key}->{$_} } 
               @$targets  }
         );
}

# }}}

1;

=pod

=head1 NAME

Pogo::Plugin::Inline

=head1 SYNOPSIS

    use Pogo::Plugin::Inline;

    my $plugin = Pogo::Plugin::Inline->new(
        conf => \&get_conf
    );

=head1 DESCRIPTION

The Inline plugin parses Pogo YAML configuration files and provides
the Pogo engine with data on 

=over 4

=item apps:

groups of targets (hosts)

=item envs:

key/value settings for targets

=item sequences:

order in which apps (targets) are processed

=item constraints:

limitations on how many apps (targets) can be processed in parallel

=back

=head1 METHODS

=over 4

=item C<new( conf => \&get_conf )>

The C<conf> parameter to the constructor defines a reference to a function
returning parsed YAML data, e.g.

    apps:
      frontend:
        - foo[1-101].east.example.com
        - foo[1-101].west.example.com
      backend:
        - bar[1-10].east.example.com
        - bar[1-10].west.example.com
    
    constraints:
      - sequences:
        - apps: [ backend, frontend ]
      - concurrency:
        - frontend: 25%
        - backend: 1

as a Perl data structure. 

=item C<fetch_target_meta>

After creating a new plugin object with the constructor explained above, 
a subsequent call of the C<fetch_target_meta()> method as in

    # Cache/Return target meta info from conf file
    my $meta_data;
    my $errcont = sub { print "Whoa! Error!\n" };
    my $cont    = sub { $meta_data = $_[0] };
    $plugin->fetch_target_meta( ["foo13.east.example.com"], 
                                $errcont, $cont );

will process the entire configuration file and cache it in memory (if it's not
cached already) and call the continuation function with the following data 
structure:

    { 'foo13.east.example.com' =>
          { 'apps' => [ 'frontend' ],
              'envs' => { 
                  'coast' => 'east'
          }
    }

Host "foo13.east.example.com" is therefore a member of the appgroup 'frontend'
and carries an environment setting of C<coast =E<gt> east>.

C<fetch_target_meta()> also handles calls to obtain meta data of
several targets at once:

    $plugin->fetch_target_meta( ["foo13.east.example.com",
                                 "foo14.east.example.com",
                                ], 
                                $errcont, $cont,
                              );

Upon completion, this will call the continuation with the following
data structure:

    { 'foo13.east.example.com' =>
          { 'apps' => [ 'frontend' ],
              'envs' => { 
                  'coast' => 'east'
          },
      'foo14.east.example.com' =>
          { 'apps' => [ 'frontend' ],
              'envs' => { 
                  'coast' => 'east'
          },
    }

To enable C<fetch_target_meta> to rely heavily on advanced caching 
techniques, it accepts an additional (and optional) C<cache_key>
parameter:

    $plugin->fetch_target_meta( ["foo13.east.example.com",
                                 "foo14.east.example.com",
                                ], 
                                $errcont, $cont,
                                { cache_key => "eastern_hosts" },
                              );

The C<cache_key> parameter ("eastern_hosts") defines the name of a
target group that contains a superset of all requested targets.
It enables the plugin to quickly check if cached data for all requested 
targets is still valid and to effectively refresh it from the source
in one fell swoop if necessary. In this way, it will not only refresh
data for targets listed in the current request, but will be ready
to serve cached data to future requests for targets belonging to the
same group. In the case outlined above, the function only gets called
for C<foo13.east.example.com> and C<foo14.east.example.com>, but if the
plugin knows that 'eastern_hosts' contains in the range
C<foo[1-100].east.example.com>, it may refresh all of them from 
a (ficticious) external source and is then prepared for the next
call when meta data on, say, C<foo42.east.example.com>, is requested.

The Inline plugin doesn't use this feature (yet), since all data
can be cached in memory indefinitely, but other plugins gain tremendous
performance benefits from using it.

=item C<expand_target>

Expands target text globs:

    # Expand target ranges
    my @targets = $plugin->expand_targets( ["host[0-9].corp.com"] );
      # @targets now holds ("host0.corp.com", "host1.corp.com", ...)

=back

=head1 Pogo Sequence and Constraints Handling

Pogo configurations allow for processing targets in carefully defined
sequences, while obeying configured limits of how many targets can be 
processed in parallel.

=head1 App Sequences

Apps (groups of targets) can be processed in defined sequences. For
example, to process the "backend" servers first, followed by the
"frontend" servers, use this:

    apps:
      frontend:
        - foo[1-101].east.example.com
        - foo[1-101].west.example.com
      backend:
        - bar[1-10].east.example.com
        - bar[1-10].west.example.com
    
    constraints:
      - sequences:
        - apps: [ backend, frontend ]

=head1 Env Sequences

Sequences aren't limited to targets defined in the C<apps> section. 
Targets can also be 'tagged' with environment settings, which then
can be used later to define in which order targets of certain 
env settings will be processed.

For example, to tag some targets with the attribute "coast" set to 
either "east" or "west", and process them east to west, use this:

    apps:
      frontend:
        - foo[1-101].east.example.com
        - foo[1-101].west.example.com
      backend:
        - bar[1-10].east.example.com
        - bar[1-10].west.example.com
    
    envs:
      coast:
        east:
          - foo[1-101].east.example.com
          - bar[1-10].east.example.com
        west:
          - foo[1-101].west.example.com
          - bar[1-10].west.example.com

    constraints:
      - env: coast
        sequences:
          - envs: [ east, west ]

The env-based sequence definition can be limited to apply to certain 
apps only:

    constraints:
      - env: coast
        sequences:
          - envs: [ east, west ]
            apps: [ frontend ]

This will process targets in the "frontend" app from "east" to "west", but 
process targets in the "backend" app unconstrained (i.e. in parallel
unless there are other restrictions).

=head2 Concurrency

To limit the number of targets being processed in parallel (and hence
the targets that are unavailable in production, e.g. during an upgrade),
constraints on apps can be defined:

    constraints:
      - concurrency:
        - frontend: 25%
        - backend: 1

This will only process 25% of all frontend machines in parallel, and 
process backend machines one at a time.

=head2 Multiple Constraints

If you have two sets of machines whose update sequence depends on two different
environment settings, simply define them in the "envs" section and then add two
different "sequences" entries (one for each env variable) in the "constraints"
section.

For example, if your database servers need to be installed first inside the
firewall and then in the colo, while your production application needs to be
install first on the east coast and then on the west coast, this setup will
accomplish the entire work:

    apps:
      web-master:
        - web-master.east.corp.com
        - web-master.west.corp.com
      web-mirror:
        - web-mirror.east.corp.com
        - web-mirror.west.corp.com
      db-master:
        - db-master.colo.corp.com
        - db-master.inside.corp.com
      db-mirror:
        - db-mirror.colo.corp.com
        - db-mirror.inside.corp.com
    
    envs:
      coast:
        east:
          - web-master.east.corp.com
          - web-mirror.east.corp.com
          - db-master.east.corp.com
        west:
          - web-master.west.corp.com
          - web-mirror.west.corp.com
          - db-master.west.corp.com
      location:
        colo:
          - db-master.colo.corp.com
          - db-mirror.colo.corp.com
        inside:
          - db-master.inside.corp.com
          - db-mirror.inside.corp.com
    
    constraints:
      - env: coast
        sequences:
          - envs: [ east, west ]
            apps: [ web-mirror, web-master ]
      - env: location
        sequences:
          - envs: [ inside, colo ]
            apps: [ db-mirror, db-master ]

This will result in a sequence of (| indicates targets installed in parallel 
with the one on the preceding line):

    web-mirror.east.corp.com 
    | web-master.east.corp.com

    web-mirror.west.corp.com 
    | web-master.west.corp.com

    db-master.inside.corp.com 
    | db-mirror.inside.corp.com

    db-master.colo.corp.com   
    | db-mirror.colo.corp.com

You could even add a third env type, "systype", which would be "web" for
webservers and "db" for database servers, and add a sequence constraint that
enforces updating database servers before web servers:

      ...
      - env: systype
        sequences:
          - envs: [ db, web ]
            apps: [ db-mirror, db-master ]

would result in a sequence of

    db-master.inside.corp.com 
    | db-mirror.inside.corp.com

    db-master.colo.corp.com   
    | db-mirror.colo.corp.com

    web-mirror.east.corp.com 
    | web-master.east.corp.com

    web-mirror.west.corp.com 
    | web-master.west.corp.com

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
