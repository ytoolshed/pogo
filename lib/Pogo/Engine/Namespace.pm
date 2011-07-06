package Pogo::Engine::Namespace;

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

use Data::Dumper;

use 5.008;
use common::sense;

use Storable qw(dclone);
use List::Util qw(min max);
use Log::Log4perl qw(:easy);
use Set::Scalar;

use Pogo::Engine::Namespace::Slot;
use Pogo::Engine::Store qw(store);
use Pogo::Common qw(merge_hash);
use Pogo::Plugin;
use JSON qw(encode_json decode_json);

# Naming convention:
# get_* retrieves something synchronously
# fetch_* retrieves something asynchronously, taking an error callback
# and a continuation as the last two args

# {{{ constructors

sub new
{
  my ( $class, $nsname ) = @_;
  my $self = {
    ns            => $nsname,
    path          => "/pogo/ns/$nsname",
    slots         => {},
    _plugin_cache => {},
  };

  bless $self, $class;
  return $self->init;
}

sub init
{
  my $self = shift;

  my $ns = $self->{ns};
  if ( !store->exists( $self->path ) )
  {
    store->create( $self->path, '' )
      or LOGCONFESS "unable to create namespace '$ns': " . store->get_error_name;
    store->create( $self->path . '/env', '' )
      or LOGCONFESS "unable to create namespace '$ns': " . store->get_error_name;
    store->create( $self->path . '/lock', '' )
      or LOGCONFESS "unable to create namespace '$ns': " . store->get_error_name;
    store->create( $self->path . '/conf', '' )
      or LOGCONFESS "unable to create namespace '$ns': " . store->get_error_name;
  }

  return $self;
}

# }}}
# {{{ accessors

sub path
{
  my ( $self, @parts ) = @_;
  return join( '', $self->{path}, @parts );
}

sub name
{
  return shift->{ns};
}

# }}}
# {{{ constraint logic

sub fetch_runnable_hosts
{
  my ( $self, $job, $hostinfo_map, $errc, $cont ) = @_;
  my @runnable;
  my %unrunnable;

  $self->fetch_all_slots(
    $job,
    $hostinfo_map,
    $errc,
    sub {
      my ( $allslots, $hostslots ) = @_;

      local *__ANON__ = 'fetch_runnable_hosts:fetch_all_slots:cont';

      my $global_lock = store->lock( 'fetch_runnable_hosts:' . $job->id );
      eval {
        foreach my $hostname ( sort { $a cmp $b } keys %$hostslots )
        {
          my $slots = $hostslots->{$hostname};

          # is this host runnable?
          my $host_is_runnable = $job->host($hostname)->is_runnable;
          INFO "Host $hostname is", ($host_is_runnable ? "" : "n't"),
               " runnable";
          next unless $host_is_runnable;

          # if any slots have predecessors, then check that they're done
          my @pred_slots;
          foreach my $slot (@$slots)
          {
            if ( exists $slot->{pred} )
            {
              push @pred_slots, @{ $slot->{pred} };
            }
          }

          #DEBUG "predecessors for $hostname: " . join ', ', map { $_->name } @pred_slots;
          my @fullpredslots = map { $_->name } ( grep { !$job->is_slot_done($_) } @pred_slots );
          if (@fullpredslots)
          {
            $unrunnable{$hostname} = join ', ', @fullpredslots;
          }
          else
          {
            my @fullslots = map { $_->name } ( grep { $_->is_full( $job, $hostname ) } @$slots );
            if (@fullslots)
            {
              $unrunnable{$hostname} = join ', ', @fullslots;
            }
            else
            {
              map { DEBUG "reserving $_->{path} for $hostname"; $_->reserve( $job, $hostname ) }
                @$slots;
              push @runnable, $hostname;
            }
          }
        }
      };

      if ($@)
      {
        store->unlock($global_lock);
        return $errc->($@);
      }

      return $cont->( \@runnable, \%unrunnable, $global_lock );
    }
  );
}

sub fetch_all_slots
{
  my ( $self, $job, $hostinfo_map, $errc, $cont ) = @_;
  my $slots = $self->{slots};

  my %hostslots   = ();
  my %to_resolve  = ();
  my @slotlookups = ();

  DEBUG "Fetching all slots of job ", $job->id;

  DEBUG sub { local $Data::Dumper::Indent = 1; 
              return "hostinfo_map: " . Dumper $hostinfo_map; };

  my $concurrent = $job->concurrent;
  if ( defined $concurrent )
  {
    my $maxdown = $concurrent;
    my $slot = $self->slot( 'locks', $job->id, 'concurrent' );

    if ( $maxdown =~ m/^(\d+)%$/ )
    {

      # maxdown will be a percentage of the hosts in the job
      my $pct = $1;
      $maxdown = max( 1, int( $pct * scalar( $job->hosts ) / 100 ) );
    }
    elsif ( !$maxdown )
    {

      # if $concurrent is 0, we run all hosts in parallel
      $maxdown = scalar $job->hosts;
    }
    $slot->{maxdown} = $maxdown;
    DEBUG "Maxdown for job ", $job->id, ": $maxdown";

    # fill out our hostslots hash
    while ( my ( $hostname, $hostinfo ) = each %$hostinfo_map )
    {
      $hostslots{$hostname} = [$slot];
    }

    DEBUG "Slots/Hostslots: ",
      sub { local $Data::Dumper::Indent = 1; 
            return "Slots: " . Dumper($slots) . 
                   "Hostslots: " . Dumper(\%hostslots); };

    # our work here should be done
    return $cont->( $slots, \%hostslots );
  }

  # this is where we handle the more complex, non-concurrent case

  my $const = $self->get_all_curs;
  my $seq   = $self->get_all_seqs;

  DEBUG Dumper [ $const, $seq ];

  # resolve all max_down_hosts for each app-env
  # debug> p $hostname
  #  foo13.west.example.com
  #
  # debug> x $hostinfo
  #  0  HASH(0x9e76008)
  #     'apps' => ARRAY(0x9e75fc8)
  #        0  'frontend'
  #     'envs' => HASH(0x9e76028)
  #        'coast' => HASH(0x9e6dff8)
  #           'west' => 1
  #
  # debug> x $seq
  #  0  HASH(0x9c55d80)
  #  'coast' => HASH(0x9c536f8)
  #     'frontend' => ARRAY(0x9e6c290)
  #         empty array
  #
  # debug> x $const
  #  0  HASH(0x9e6bad0)
  #  'coast' => HASH(0x9c558e0)
  #     'backend' => '"1"'
  #     'frontend' => '"25%"'

  while ( my ( $hostname, $hostinfo ) = each %$hostinfo_map )
  {
    $hostslots{$hostname} = [];

    #$DB::single = 1;

    foreach my $app ( @{ $hostinfo->{apps} } )
    {
      foreach my $envtype ( keys %{ $hostinfo->{envs} } )
      {
          foreach my $env ( keys %{ $hostinfo->{envs}->{$envtype} } )
          {
              # e.g. $app=frontend $envtype=coast $env=west

              my $slot = $self->slot( $app, $envtype, $env );

              # if we have predecessors in the sequence for this 
              # app/environment, get those slots too
              if ( exists $seq->{$envtype} && 
                   exists $seq->{$envtype}->{$app} )
              {
                $slot->{pred} = [ map { $self->slot( $_, $envtype, $env ) } 
                                      @{ $seq->{$envtype}->{$app} } ];
                DEBUG "Sequence predecessors for "
                . $slot->name . ": "
                . join( ", ", map { $_->name } @{ $slot->{pred} } );
              }
              push @{ $hostslots{$hostname} }, $slot;

              next unless exists $const->{$envtype} and
                          exists $const->{$envtype}->{$app};

              my $concur = $const->{$envtype}->{$app};
              if ( $concur !~ m{^(\d+)%$} )
              {
                # not a percentage, a literal
                $slot->{maxdown} = $concur;
              }
              else
              {
                # we need to resolve the percentage, and we do so asyncronously.
                my $pct    = $1;
                my $appexp = $self->app_members($app);
                my $envexp = $self->env_members($env);

                $to_resolve{$appexp} = 1;
                $to_resolve{$envexp} = 1;

                push @slotlookups,
                [ $slot, $appexp, $envexp, $pct ];   # $pct in these to be written 
                                                     # by resolv $cont below
              }
            }
       }
    }
  }

  # note that we pass through this whether or not we need to do any expansions
  # the foreach loop is skipped and we hit $cont directly.
  $self->resolve(
    [ keys %to_resolve ],
    $errc,
    sub {
      my ($resolved) = @_;
      foreach my $lookup (@slotlookups)
      {
        my ( $slot, $appexp, $envexp, $pct ) = @$lookup;
        my $apptargets = Set::Scalar->new( @{ $resolved->{$appexp} } );
        my $envtargets = Set::Scalar->new( @{ $resolved->{$envexp} } );

        # TODO: do we need to speed this up with Bit::Vector?
        my $nhosts = scalar @{ $apptargets->intersection($envtargets) };

        $slot->{maxdown} = max( 1, int( $pct * $nhosts / 100 ) );
        DEBUG "slot: @$lookup -> $slot->{maxdown} max down";
      }

      return $cont->( $slots, \%hostslots );
    }
  );
}

sub slot
{
  my ( $self, $app, $envk, $envv ) = @_;
  my $slots = $self->{slots};
  $slots->{ $app, $envk, $envv }
    ||= Pogo::Engine::Namespace::Slot->new( $self, $app, $envk, $envv );
  return $slots->{ $app, $envk, $envv };
}

sub _has_constraints
{
  my ( $self, $app, $k ) = @_;

  # TODO: potential optimization, cache these to avoid probing storage
  if ( !defined $k )
  {
    return store->exists( $self->path( '/conf/constraints/', $app ) );
  }
  else
  {
    return store->exists( $self->path("/conf/constraints/$app/$k") );
  }

  return;
}

sub unlock_job
{
  my ( $self, $job ) = @_;

  foreach my $env ( store->get_children( $self->path('/env/') ) )
  {
    foreach my $jobhost ( store->get_children( $self->path( '/env/', $env ) ) )
    {
      my ( $host_jobid, $hostname ) = split /_/, $jobhost;
      if ( $job->id eq $host_jobid )
      {
        store->delete( $self->path("/env/$env/$jobhost") );
      }
    }
    store->delete( $self->path( '/env/', $env ) );
  }
}

# }}}
# {{{ resolve

# this is where we need to do plugin-based lookups
# we find/initialize the plugins and fire off
# BATCHSIZE'd chunks of lookups
sub resolve
{
  my ( $self, $lookups, $errc, $cont ) = @_;
  DEBUG Dumper $lookups;
}

# }}}
# {{{ config setters

sub set_conf
{
  my ( $self, $conf_ref ) = @_;

  # copy the conf ref, since we're going to modify the crap out of it below
  my $conf_in = dclone $conf_ref;
  my $conf    = {};

  my $name = $self->name;

  # globals processing
  foreach my $global ( keys %{ $conf_in->{globals} } )
  {
    DEBUG "processing '$name/global/$global'";
    $conf->{globals}->{$global} = delete $conf_in->{globals}->{$global};
  }

  delete $conf_in->{globals};

  # plugin processing
  foreach my $plugin ( keys %{ $conf_in->{plugins} } )
  {
    DEBUG "processing '$name/plugin/$plugin'";
    $conf->{plugins}->{$plugin} = delete $conf_in->{plugins}->{$plugin};
  }

  delete $conf_in->{plugins};

  # app processing
  foreach my $app ( keys %{ $conf_in->{apps} } )
  {
    DEBUG "processing '$name/app/$app'";

    $conf->{apps}->{$app} = delete $conf_in->{apps}->{$app};
  }

  delete $conf_in->{apps};

  # env processing
  foreach my $env ( keys %{ $conf_in->{envs} } )
  {
    DEBUG "processing '$name/env/$env'";

    # provider-processing code goes here
    $conf->{envs}->{$env} = delete $conf_in->{envs}->{$env};
  }

  delete $conf_in->{envs};

  #$DB::single = 1;

  # constraint processing
  foreach my $c_env_type ( keys %{ $conf_in->{constraints} } )
  {
    DEBUG "processing '$name/constraints/$c_env_type'";

    # ensure that the apps we're constraining actually exist
    my $cur = delete $conf_in->{constraints}->{$c_env_type}->{concurrency};
    my $seq = delete $conf_in->{constraints}->{$c_env_type}->{sequence};
    my @err = keys %{ $conf_in->{constraints}->{$c_env_type} };

    if ( @err > 0 )
    {
      LOGDIE "unknown config parameter '$err[0]'";
    }

    # map sequences
    LOGDIE "config error: sequences expects an array"
      unless ( $seq && ref $seq eq 'ARRAY' );

    #    $conf_out->{seq}->{pred}->{$c_env_type};
    #    $conf_out->{seq}->{succ}->{$c_env_type};

    foreach my $seq_c (@$seq)
    {
      LOGDIE "config error: sequences must be arrays"
        unless ref $seq_c eq 'ARRAY';
      LOGDIE "config error: sequences must have at least two elements"
        if scalar @$seq_c < 2;

      for ( my $i = 1; $i < @$seq_c; $i++ )
      {
        my ( $first, $second ) = @{$seq_c}[ $i - 1, $i ];

        LOGDIE "unknown application '$first'"
          unless exists $conf->{apps}->{$first};

        LOGDIE "unknown application '$second'"
          unless exists $conf->{apps}->{$second};

        # $second requires $first to go first within $env
        # $first is a predecessor of $second
        # $second is a successor of $first
        $conf->{seq}->{pred}->{$c_env_type}->{$second}->{$first} = 1;
        $conf->{seq}->{succ}->{$c_env_type}->{$first}->{$second} = 1;
      }
    }

    # transform concurrency
    foreach my $cur_c (@$cur)
    {
      while ( my ( $app, $max ) = each %$cur_c )
      {
        LOGDIE "unknown application '$app'"
          unless exists $conf->{apps}->{$app};
        if ( $max !~ /^\d+$/ && $max !~ /^(\d+)%$/ )
        {
          LOGDIE "invalid constraint for '$app': '$max'";
        }
        $conf->{cur}->{$c_env_type}->{$app} = $max;
      }
    }
  }

  delete $conf_in->{constraints};

  my @err = keys %{$conf_in};

  if ( @err > 0 )
  {
    LOGDIE "unknown config parameter '$err[0]'";
  }

  undef $conf_in;

  eval { _write_conf( $self->{path}, $conf ) };
  if ($@)
  {
    LOGDIE "couldn't load config: $@";
  }

  return $self;
}

sub parse_deployment
{
  my ( $self, $conf_in, $deployment_name, $data ) = @_;
  my $conf_out = {};

  return $conf_out;
}

sub _write_conf
{
  my ( $path, $conf ) = @_;
  DEBUG "writing $path";

  store->delete_r("$path/conf")
    or WARN "Couldn't delete_r '$path/conf': " . store->get_error_name;
  store->create( "$path/conf", '' )
    or WARN "Couldn't create '$path/conf': " . store->get_error_name;
  _set_conf_r( "$path/conf", $conf );
}

sub _set_conf_r
{
  my ( $path, $node ) = @_;
  my $json = JSON->new->utf8->allow_nonref;
  foreach my $k ( keys %$node )
  {
    my $v = $node->{$k};
    my $r = ref($v);
    my $p = "$path/$k";

    # that's all, folks
    if ( !$r )
    {
      store->create( $p, '' )
        or WARN "couldn't create '$p': " . store->get_error_name;
      store->set( $p, $json->encode($v) )
        or WARN "couldn't set '$p': " . store->get_error_name;
    }
    elsif ( $r eq 'HASH' )
    {
      store->create( $p, '' )
        or WARN "couldn't create '$p': " . store->get_error_name;
      _set_conf_r( $p, $v );
    }
    elsif ( $r eq 'ARRAY' )
    {
      store->create( $p, '' )
        or WARN "couldn't create '$p': " . store->get_error_name;
      for ( my $node = 0; $node < scalar @$v; $node++ )
      {
        store->create( "$p/$node", '' )
          or WARN "couldn't create '$p/$node': " . store->get_error_name;

        store->set( "$p/$node", $json->encode( $v->[$node] ) )
          or WARN "couldn't set '$p/$node': " . store->get_error_name;

      }
    }
  }
}

#}}}
# {{{ config getters

# recursively traverse conf/ dir and build hash
sub _get_conf_r
{
  my $path = shift;
  my $c    = {};
  foreach my $node ( store->get_children($path) )
  {
    my $p = "$path/$node";
    my $v = store->get($p);
    if ($v)
    {
      $c->{$node} = JSON->new->utf8->allow_nonref->decode($v);
    }
    else
    {
      $c->{$node} = _get_conf_r($p);
    }
  }
  return numhash_to_array_r( $c );
}

sub numhash_to_array_r {
  my ( $node ) = @_;

  my $num_keys = 0;

  for my $key ( keys %$node ) {
      my $val = $node->{ $key };
      if( ref( $val ) eq "HASH" ) {
          $node->{ $key } = numhash_to_array_r( $val );
      }
      $num_keys++ if $key =~ /^\d+$/;
  }

  if( $num_keys and $num_keys == scalar keys %$node ) {
      my @a = ();
      for my $idx (keys %$node) {
          $a[ $idx ] = $node->{$idx};
      }
      return \@a;
  }

  return $node;
}

sub get_conf
{
  my $self = shift;
  return _get_conf_r( $self->{path} . "/conf" );
}

sub get_cur
{
  my ( $self, $app, $key ) = @_;
  my $c = store->get( $self->{path} . "/conf/cur/$app/$key" );
  return JSON->new->utf8->allow_nonref->decode($c);
}

sub get_curs
{
  my ( $self, $app ) = @_;
  my $path = $self->{path} . "/conf/cur/$app";
  my %c = map { $_ => $self->get_cur( $app, $_ ) } store->get_children($path);

  DEBUG "constraints for $app: " . join( ",", keys %c );
  return \%c;
}

sub get_all_curs
{
  my $self = shift;
  my $path = $self->{path} . "/conf/cur";
  return { map { $_ => $self->get_curs($_) } store->get_children($path) };
}

sub app_members {
  my $self = shift;
  my $app  = shift;

  my $path = $self->{path} . "/conf/apps/$app";
  return store->get_children("$path");
}

sub env_members {
  my $self      = shift;
  my $envtype   = shift;
  my $envvalue  = shift;

  my $path = $self->{path} . "/conf/envs/$envtype/$envvalue";
  return store->get_children("$path");
}

sub get_all_seqs
{
  my $self = shift;
  my $path = $self->{path} . "/conf/seq/pred";
  my %seq;
  foreach my $env ( store->get_children($path) )
  {
    my $p = "$path/$env";
    my %apps = map { $_ => [ store->get_children("$p/$_") ] } store->get_children($p);
    $seq{$env} = \%apps;
  }
  return \%seq;
}

sub get_conf_apps
{
  my ($self) = @_;
  my $path = $self->{path} . "/conf/apps";

  return _get_conf_r($path);
}

#}}}
# {{{ apps

sub filter_apps
{
  my ( $self, $apps ) = @_;

  my %constraints = map { $_ => 1 } store->get_children( $self->path('/conf/constraints') );

  # FIXME: if you have sequences for which there are no constraints, we might
  # improperly ignore them here.  Can't think of a straightforward fix and
  # can't tell whether it will ever be a problem, so leaving for now.

  return [ grep { exists $constraints{$_} } @$apps ];
}

# }}}
# {{{ sequences

sub is_sequence_blocked
{
  my ( $self, $job, $host ) = @_;

  my ( $nblockers, @bywhat ) = (0);

  foreach my $env ( @{ $host->info->{env} } )
  {
    my $k = $env->{key};
    my $v = $env->{value};

    foreach my $app ( @{ $host->info->{apps} } )
    {
      my @preds = store->get_children( $self->path("/conf/sequences/pred/$k/$app") );
      foreach my $pred (@preds)
      {
        my $n = store->get_children( $job->{path} . "/seq/$pred" . "_$k" . "_$v" );
        if ($n)
        {
          $nblockers += $n;
          push @bywhat, "$k $v $pred";
        }
      }
    }
  }
  return ( $nblockers, join( ', ', @bywhat ) );    # cosmetic, this is what shows up in the UI
}

sub get_seq_successors
{
  my ( $self, $envk, $app ) = @_;

  my @successors = ($app);
  my @results;

  while (@successors)
  {
    $app = pop @successors;
    my @s = store->get_children( $self->path("/conf/sequences/succ/$envk/$app") );
    push @results,    @s;
    push @successors, @s;
  }

  return @results;
}

# }}}
# {{{ plugin stuff

sub target_plugin
{
  my $self = shift;
  if ( !exists $self->{_plugin_cache}->{planner} ){
      $self->{_plugin_cache}->{planner} = Pogo::Plugin->load( 'Planner', { required_methods => ['expand_targets','fetch_target_meta'] } );

      # set conf code and namespace
      $self->{_plugin_cache}->{planner}->conf( sub { $self->get_conf } );
      $self->{_plugin_cache}->{planner}->namespace( $self->name );
  }

  return $self->{_plugin_cache}->{planner};
}

# }}}
# {{{ expand_targets

sub expand_targets
{
  my ( $self, $target ) = @_;
  return $self->target_plugin->expand_targets($target);
}

# }}}
# {{{ fetch_target_meta

sub fetch_target_meta
{
  my ( $self, $target, $nsname, $errc, $cont ) = @_;
  DEBUG __PACKAGE__, "::fetch_target_meta";
  return $self->target_plugin->fetch_target_meta( $target, $nsname, 
                                                  $errc, $cont );
}

#}}}
# {{{ deprecated unlock_host
# remove active host from all environments
# apparently this is deprecated?
sub unlock_host
{
  my ( $self, $job, $host, $unlockseq ) = @_;
  DEBUG __PACKAGE__, "::unlock_host";

  return LOGDIE "unlock_host is deprecated";

  # iterate over /pogo/host/$host/<children>
  my $path = "/pogo/job/$host/host/$host";
  return unless store->exists($path);

  my $n = 0;
  foreach my $child ( store->get_children($path) )
  {
    next if substr( $child, 0, 1 ) eq '_';

    # get the node contents $app, $k, $v
    my $child_path = $path . '/' . $child;

    if ( substr( $child, 0, 4 ) eq 'seq_' )
    {
      next unless $unlockseq;

      # remove sequence lock
      my $node = substr( $child, 4 );
      store->delete("/pogo/job/$job/seq/$node/$host");
      if ( ( scalar store->get_children("/pogo/job/$job/seq/$node") ) == 0 )
      {
        store->delete("/pogo/job/$job/seq/$node");
      }
    }
    else
    {
      my $job_host = $job->id . '_' . $host;

      # remove environment lock
      # delete /pogo/env/$app_$k_$v
      store->delete("/pogo/env/$child/$job_host")
        or ERROR "unable to remove '/pogo/env/$child/$job_host' from '$child_path': "
        . store->get_error;

      # clean up empty env nodes
      if ( ( scalar store->get_children("/pogo/env/$child") ) == 0 )
      {
        store->delete("/pogo/env/$child");
      }
    }

    store->delete($child_path)
      or LOGDIE "unable to remove $child_path: " . store->get_error;
    $n++;
  }

  return $n;
}    # }}}

1;

=pod

=head1 NAME

  Pogo::Engine::Namespace

=head1 SYNOPSIS

  # internal pogo api

=head1 DESCRIPTION

This module contains helper functions for configuration and execution of
the constraints engine. To set the configuration for the namespace, use

    $ns->set_conf($conf);

where $conf is a data structure obtained from a YAML file as shown below.
The configuration is plugin-driven, and by default, it uses the
Inline.pm plugin:

    plugins:
      targets: Pogo::Plugin::Inline

The Inline plugin allows
(see the detailed Pogo::Plugin::Inline doc for details) for
defining apps (targets, hosts), envs (key/value settings for targets), 
sequences and constraints, like

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
      coast:
        concurrency:
          - frontend: 25%
          - backend: 1
        sequence:
          - [ backend, frontend ]

which Pogo::Engine::Namespace transforms into a directory/file
hierarchy in ZooKeeper for later processing by the dispatcher. 

The apps (targets) defined above are stored like this:

    /pogo/ns/nsname/conf/apps/backend/0: ["bar[1-10].east.example.com"]
    /pogo/ns/nsname/conf/apps/backend/1: ["bar[1-10].west.example.com"]
    /pogo/ns/nsname/conf/apps/frontend/0: ["foo[1-101].east.example.com"]
    /pogo/ns/nsname/conf/apps/frontend/1: ["foo[1-101].west.example.com"]

Constraints on 

For every environment type (e.g. 'coast'), the apps are mapped 
The constraints:

    /pogo/ns/nsname/conf/cur/coast/backend: ["1"]
    /pogo/ns/nsname/conf/cur/coast/frontend: ["25%"]

Env settings:

    /pogo/ns/nsname/conf/envs/coast/east/0: ["foo[1-101].east.example.com"]
    /pogo/ns/nsname/conf/envs/coast/east/1: ["bar[1-10].east.example.com"]
    /pogo/ns/nsname/conf/envs/coast/west/0: ["foo[1-101].west.example.com"]
    /pogo/ns/nsname/conf/envs/coast/west/1: ["bar[1-10].west.example.com"]

Sequences:

    /pogo/ns/nsname/conf/seq/pred/coast/frontend/backend
    /pogo/ns/nsname/conf/seq/succ/coast/backend/frontend

And even the plugin gets stored:

    /pogo/ns/nsname/conf/plugins/targets: ["Pogo::Plugin::Inline"]

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
