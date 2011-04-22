package Pogo::Engine::Namespace;
use strict;
use warnings;

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

use Pogo::Common qw(merge_hash);
use JSON qw(encode_json decode_json);

# Naming convention:
# get_* retrieves something synchronously
# fetch_* retrieves something asynchronously, taking an error callback
# and a continuation as the last two args

# {{{ constructors

sub new
{
  my ( $class, @options ) = @_;

  my %options = ();

  # legacy mode: new($nsname)
  if ( @options == 1 )
  {
    $options{nsname} = shift @options;
  }
  else
  {
    %options = @options;
  }

  my $self = {
    ns            => $options{nsname},
    path          => "/pogo/ns/$options{ nsname }",
    slots         => {},
    store         => undef,
    get_slot      => undef,
    _plugin_cache => {},
    %options,
  };

  if ( !defined $options{store} )
  {
    require Pogo::Engine::Store;
    $self->{store} = Pogo::Engine::Store::store();
  }

  if ( !defined $options{get_slot} )
  {
    require Pogo::Engine::Namespace::Slot;
    $self->{get_slot} = sub {
      my ( $self, $app, $envk, $envv ) = @_;
      my $slots = $self->{slots};
      $slots->{ $app, $envk, $envv }
        ||= Pogo::Engine::Namespace::Slot->new( $self, $app, $envk, $envv );
      return $slots->{ $app, $envk, $envv };
    };
  }

  if ( !exists $options{nsname} )
  {
    die "Internal error: param 'nsname' missing";
  }

  bless $self, $class;
  return $self->init;
}

sub init
{
  my $self = shift;

  my $ns = $self->{ns};
  if ( !$self->{store}->exists( $self->path ) )
  {
    $self->{store}->create( $self->path, '' )
      or LOGCONFESS "unable to create namespace '$ns': " . $self->{store}->get_error_name;
    $self->{store}->create( $self->path . '/env', '' )
      or LOGCONFESS "unable to create namespace '$ns': " . $self->{store}->get_error_name;
    $self->{store}->create( $self->path . '/lock', '' )
      or LOGCONFESS "unable to create namespace '$ns': " . $self->{store}->get_error_name;
    $self->{store}->create( $self->path . '/conf', '' )
      or LOGCONFESS "unable to create namespace '$ns': " . $self->{store}->get_error_name;
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

      my $global_lock = $self->{store}->lock( 'fetch_runnable_hosts:' . $job->id );
      eval {
        foreach my $hostname ( sort { $a cmp $b } keys %$hostslots )
        {
          my $slots = $hostslots->{$hostname};

          # is this host runnable?
          next unless $job->host($hostname)->is_runnable;

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
        $self->{store}->unlock($global_lock);
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

  DEBUG Dumper $hostinfo_map;

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

    # fill out our hostslots hash
    while ( my ( $hostname, $hostinfo ) = each %$hostinfo_map )
    {
      $hostslots{$hostname} = [$slot];
    }

    # our work here should be done
    return $cont->( $slots, \%hostslots );
  }

  # this is where we handle the more complex, non-concurrent case

  my $const = $self->get_all_curs;
  my $seq   = $self->get_all_seqs;

  DEBUG Dumper [ $const, $seq ];

  # resolve all max_down_hosts for each app-env
  while ( my ( $hostname, $hostinfo ) = each %$hostinfo_map )
  {
    $hostslots{$hostname} = [];
    foreach my $app ( @{ $hostinfo->{apps} } )
    {
      foreach my $env ( @{ $hostinfo->{envs} } )
      {
        my ( $etype, $ename ) = ( $env->{key}, $env->{value} );

        # skip if there are no constraints for this environment
        next if ( !exists $const->{app}->{$etype} );

        my $slot = $self->slot( $app, $etype, $ename );

        # if we have predecessors in the sequence for this app/environment, get
        # those slots too
        if ( exists $seq->{$etype} && exists $seq->{$ename}->{$app} )
        {
          $slot->{pred} = [ map { $self->slot( $_, $etype, $ename ) } @{ $seq->{$etype}->{$app} } ];
          DEBUG "Sequence predecessors for "
            . $slot->name . ": "
            . join( ", ", map { $_->name } @{ $slot->{pred} } );
        }
        push @{ $hostslots{$hostname} }, $slot;

        my $concur = $const->{$app}->{$etype};
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
            [ $slot, $appexp, $envexp, $pct ];   # $pct in these to be written by resolv $cont below
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

  return $self->{get_slot}->( $self, $app, $envk, $envv );
}

sub _has_constraints
{
  my ( $self, $app, $k ) = @_;

  # TODO: potential optimization, cache these to avoid probing storage
  if ( !defined $k )
  {
    return $self->{store}->exists( $self->path( '/conf/constraints/', $app ) );
  }
  else
  {
    return $self->{store}->exists( $self->path("/conf/constraints/$app/$k") );
  }

  return;
}

sub unlock_job
{
  my ( $self, $job ) = @_;

  foreach my $env ( $self->{store}->get_children( $self->path('/env/') ) )
  {
    foreach my $jobhost ( $self->{store}->get_children( $self->path( '/env/', $env ) ) )
    {
      my ( $host_jobid, $hostname ) = split /_/, $jobhost;
      if ( $job->id eq $host_jobid )
      {
        $self->{store}->delete( $self->path("/env/$env/$jobhost") );
      }
    }
    $self->{store}->delete( $self->path( '/env/', $env ) );
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

  # use default plugins if none are defined
  #if ( !defined $conf_in->{plugins} )
  #{
  #  $conf_in->{plugins}->{targets} = 'Pogo::Plugin::Inline';
  #}

  my $name = $self->name;

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
        # we just make sure these exist, don't define them
        $conf->{seq}->{pred}->{$c_env_type}->{$second}->{$first};
        $conf->{seq}->{succ}->{$c_env_type}->{$first}->{$second};
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

  eval { $self->_write_conf( $self->{path}, $conf ) };
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
  my ( $self, $path, $conf ) = @_;
  DEBUG "writing $path";

  $self->{store}->delete_r("$path/conf")
    or WARN "Couldn't delete_r '$path/conf': " . $self->{store}->get_error_name;
  $self->{store}->create( "$path/conf", '' )
    or WARN "Couldn't create '$path/conf': " . $self->{store}->get_error_name;
  $self->_set_conf_r( "$path/conf", $conf );
}

sub _set_conf_r
{
  my ( $self, $path, $node ) = @_;
  my $json = JSON->new->utf8->allow_nonref;
  foreach my $k ( keys %$node )
  {
    my $v = $node->{$k};
    my $r = ref($v);
    my $p = "$path/$k";

    # that's all, folks
    if ( !$r )
    {
      $self->{store}->create( $p, '' )
        or WARN "couldn't create '$p': " . $self->{store}->get_error_name;
      $self->{store}->set( $p, $json->encode($v) )
        or WARN "couldn't set '$p': " . $self->{store}->get_error_name;
    }
    elsif ( $r eq 'HASH' )
    {
      $self->{store}->create( $p, '' )
        or WARN "couldn't create '$p': " . $self->{store}->get_error_name;
      $self->_set_conf_r( $p, $v );
    }
    elsif ( $r eq 'ARRAY' )
    {
      $self->{store}->create( $p, '' )
        or WARN "couldn't create '$p': " . $self->{store}->get_error_name;
      for ( my $node = 0; $node < scalar @$v; $node++ )
      {
        $self->{store}->create( "$p/$node", '' )
          or WARN "couldn't create '$p/$node': " . $self->{store}->get_error_name;

        $self->{store}->set( "$p/$node", $json->encode( $v->[$node] ) )
          or WARN "couldn't set '$p/$node': " . $self->{store}->get_error_name;

      }
    }
  }
}

#}}}
# {{{ config getters

# recursively traverse conf/ dir and build hash
sub _get_conf_r
{
  my ( $self, $path ) = @_;
  my $c = {};
  foreach my $node ( $self->{store}->get_children($path) )
  {
    my $p = "$path/$node";
    my $v = $self->{store}->get($p);
    if ($v)
    {
      $c->{$node} = JSON->new->utf8->allow_nonref->decode($v);
    }
    else
    {
      $c->{$node} = $self->_get_conf_r($p);
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
  return $self->_get_conf_r( $self->{path} . "/conf" );
}

sub get_cur
{
  my ( $self, $app, $key ) = @_;
  my $c = $self->{store}->get( $self->{path} . "/conf/cur/$app/$key" );
  return $c;
}

sub get_curs
{
  my ( $self, $app ) = @_;
  my $path = $self->{path} . "/conf/cur/$app";
  my %c = map { $_ => $self->get_cur( $app, $_ ) } $self->{store}->get_children($path);

  DEBUG "constraints for $app: " . join( ",", keys %c );
  return \%c;
}

sub get_all_curs
{
  my $self = shift;
  my $path = $self->{path} . "/conf/cur";
  return { map { $_ => $self->get_curs($_) } $self->{store}->get_children($path) };
}

sub get_all_seqs
{
  my $self = shift;
  my $path = $self->{path} . "/conf/seq/pred";
  my %seq;
  foreach my $env ( $self->{store}->get_children($path) )
  {
    my $p = "$path/$env";
    my %apps =
      map { $_ => [ $self->{store}->get_children("$p/$_") ] } $self->{store}->get_children($p);
    $seq{$env} = \%apps;
  }
  return \%seq;
}

sub get_conf_apps
{
  my ($self) = @_;
  my $path = $self->{path} . "/conf/apps";

  return $self->_get_conf_r($path);
}

#}}}
# {{{ apps

sub filter_apps
{
  my ( $self, $apps ) = @_;

  my %constraints =
    map { $_ => 1 } $self->{store}->get_children( $self->path('/conf/constraints') );

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
      my @preds = $self->{store}->get_children( $self->path("/conf/sequences/pred/$k/$app") );
      foreach my $pred (@preds)
      {
        my $n = $self->{store}->get_children( $job->{path} . "/seq/$pred" . "_$k" . "_$v" );
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
    my @s = $self->{store}->get_children( $self->path("/conf/sequences/succ/$envk/$app") );
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
  my $name = $self->get_conf->{plugins}->{targets} || 'Pogo::Plugin::Inline';

  if ( !exists $self->{_plugin_cache}->{$name} )
  {
    eval "use $name;";
    # this is a coderef because we want to make sure the data is fresh
    # the plugin should do caching of it's own metadata, not the configuration
    $self->{_plugin_cache}->{$name} = $name->new(
      conf      => sub { $self->get_conf },
      namespace => $self->name,
    );
  }

  return $self->{_plugin_cache}->{$name};
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
  my ( $self, $target, $errc, $cont ) = @_;
  return $self->target_plugin->fetch_target_meta( $target, $errc, $cont );
}

#}}}
# {{{ deprecated unlock_host
# remove active host from all environments
# apparently this is deprecated?
sub unlock_host
{
  my ( $self, $job, $host, $unlockseq ) = @_;

  return LOGDIE "unlock_host is deprecated";

  # iterate over /pogo/host/$host/<children>
  my $path = "/pogo/job/$host/host/$host";
  return unless $self->{store}->exists($path);

  my $n = 0;
  foreach my $child ( $self->{store}->get_children($path) )
  {
    next if substr( $child, 0, 1 ) eq '_';

    # get the node contents $app, $k, $v
    my $child_path = $path . '/' . $child;

    if ( substr( $child, 0, 4 ) eq 'seq_' )
    {
      next unless $unlockseq;

      # remove sequence lock
      my $node = substr( $child, 4 );
      $self->{store}->delete("/pogo/job/$job/seq/$node/$host");
      if ( ( scalar $self->{store}->get_children("/pogo/job/$job/seq/$node") ) == 0 )
      {
        $self->{store}->delete("/pogo/job/$job/seq/$node");
      }
    }
    else
    {
      my $job_host = $job->id . '_' . $host;

      # remove environment lock
      # delete /pogo/env/$app_$k_$v
      $self->{store}->delete("/pogo/env/$child/$job_host")
        or ERROR "unable to remove '/pogo/env/$child/$job_host' from '$child_path': "
        . $self->{store}->get_error;

      # clean up empty env nodes
      if ( ( scalar $self->{store}->get_children("/pogo/env/$child") ) == 0 )
      {
        $self->{store}->delete("/pogo/env/$child");
      }
    }

    $self->{store}->delete($child_path)
      or LOGDIE "unable to remove $child_path: " . $self->{store}->get_error;
    $n++;
  }

  return $n;
}    # }}}

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
