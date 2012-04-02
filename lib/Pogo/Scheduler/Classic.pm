package Pogo::Scheduler::Classic;
use strict;
use Log::Log4perl qw(:easy);
use Template;
use Template::Parser;
use Template::Stash;
use YAML::Syck qw(Load LoadFile);
use base qw( Pogo::Scheduler );

###########################################
sub new {
###########################################
    my( $class, %options ) = @_;

    my $self = {
        %options,
    };

    bless $self, $class;

    return $self;
}

###########################################
sub config {
###########################################
    my( $self ) = @_;

    return $self->{ config };
}

###########################################
sub config_load {
###########################################
    my( $self, $yaml ) = @_;

    if( ref $yaml eq "SCALAR" ) {
        $self->{ config } = Load( $$yaml );
    } else {
        $self->{ config } = LoadFile( $yaml );
    }

    my $vars = $self->{ config }->{ tag };

      # unravel macros
    $self->vars_interp_recurse( $self->{ config }->{ sequence }, $vars );
}

###########################################
sub vars_interp_recurse {
###########################################
    my( $self, $data, $vars ) = @_;

    if( ref( $data ) eq "" ) {
        if( $data =~ /(?:\$([\w.]+))/ ) {
            my $varname = $1;
            my $stash = Template::Stash->new( $vars );
            my $val = $stash->get( $varname );
            $_[1] = $val;
        }
    } elsif( ref( $data ) eq "HASH" ) {
        for my $key ( keys %$data ) {
            $self->vars_interp_recurse( $data->{ $key }, $vars );
        }
    } elsif( ref( $data ) eq "ARRAY" ) {
        for my $ele ( @$data ) {
            $self->vars_interp_recurse( $ele, $vars );
        }
    }
}

1;

__END__

=head1 NAME

Pogo::Scheduler::Classic - Pogo Scheduler supporting Sequences and Constraints

=head1 SYNOPSIS

    use Pogo::Scheduler::Classic;

=head1 DESCRIPTION

Pogo can be configured to apply predefined rules during deployments. Features
include 

=over 4

=item B<Tags>

Hosts can be tagged with labels and assigned a value.  Example:

    tag:
      colo:
        north_america:
          - host1
          - host2
        south_east_asia:
          - host3
          - host4

This defines that host1 carries a tag C<colo> that has the value 
C<north_america>.

All hosts carrying a specific tag value can be referred to later on with
the following notation:

    $tagname.colo.tag_value

For example, to refer to all hosts carrying the tag C<colo> with a value
C<north_america>, use C<$colo.north_america>.

To refer to all hosts carrying a specific tag, regardless of its value,
use the

    $tagname

notation. For example, to refer to all hosts carrying a C<colo> tag, 
regardless of its value, use C<$colo>.

=item B<Sequences>

If one host or hostgroup must be finished before the next one in 
a sequence can be started, this dependency can be defined in a sequence:

    sequence:
      - [ $colo.north_america, $colo.south_east_asia ]

The statement above defines that all hosts carrying the tag C<colo> will be
processed in an order that makes sure that those carrying the tag value
C<north_america> will be finished before any of the hosts carrying the C<colo>
tag value C<south_east_asia> will be started.

With the configuration shown at the start of this section, and no other
constraints, this will cause the scheduler to process the hosts in the
following order:

    - host1 host2 (wait until both are finished)
    - host3 host4

=item B<Constraints>

To limit the number of hosts handled in parallel, constraints can be put in
place. For example, 

    constraint:
      $colo.north_america: 3
      $colo.south_east_asia: 15%

limits the number of hosts processed in parallel in the C<north_america> 
colocation to 3, and in the C<south_east_asia> colo to 15%. To apply a 
constraint evenly on all hosts carrying a specific tag, grouped by tag value,
use

    constraint:
      $colo: 3

This will allow Pogo to process up to 3 hosts of both the C<north_america> and
C<south_korea> colos in parallel.

=back 

=head2 Example

Let's take a look at the following configuration and how pogo will handle it:

    tag:
      colo:
        north_america:
          - host1
          - host2
          - host3
        south_east_asia:
          - host4
          - host5
          - host6

    sequence:
      - [ $colo.north_america, $colo.south_east_asia ] 

    constraint:
      $colo: 2

Now if you ask Pogo to process all hosts carrying the C<colo> tag (or
specify C<host[1-6]>), the following will happen ("|" indicates that the
following line starts in parallel):

    host1 start 
    | host2 start
    host1 end
    | host3 start
    host2 end
    host3 end

    host4 start
    | host5 start
    host4 end
    | host6 start
    host5 end
    host6 end

Since the constraint says that we can process up to two hosts per colo
in parallel, Pogo starts with host1 and host2 in parallel. It won't throw
in any hosts from colo C<south_east_asia> yet, because of the sequence 
definition
that says that colo C<north_america> has to be completed first. As soon as
either host1 or host2 are done, 
Pogo starts host3, maximizing the resource constraint
of 2 hosts per colo. While there are still hosts remaining in colo 
C<north_america>, however, it cannot proceed with any in
colo C<south_east_asia> yet, because of the earlier sequence requirement.
Only when host1, host2, and host3 are all completed, it starts both 
host4 and host5 in parallel, again maximizing the per-colo resource 
constraint of 2.

=head2 Combining Tags

Tags can be combined (boolean AND) by nesting them. If an entry
doesn't refer to a value but an underlying key-value structure, the
Pogo configuration will apply the setting to all targets matching the
chain of tags that leads to an eventual value.

For example, if a constraint applies to all hosts tagged C<frontend> 
(regardless of value) in colo C<north_america>, use

    constraint:
      $frontend:
         $colo.north_america: 2

=head2 External Tag Resolvers

In your organization, you might have custom rules on how to 'tag' hosts or
combine them into groups. This is why the Pogo configuration format supports
I<custom tag resolvers>, a plugin system that allows you to add customized 
logic.

If a tag cannot be resolved into a list of targets, the configurator will
try to load a Plugin with the tag's name.

For example, with

    constraint:
      $_MyRules[my_db_server]: 2

and no tag C<_MyRules> defined anywhere in the configuration file, the
scheduler will look for C<MyRules.pm> in

    lib/Pogo/Scheduler/Config/Plugin

and call its C<targets()> method with a parameter of C<my_db_server> 
to obtain all targets in the 'my_db_server' group.

=head2 Slot Algorithm

To determine runnable hosts and put them onto the run queue, the algorithm
needs to iterate over all not yet active hosts of a job, and evaluate
for each if adding it would violate one of the predefined restrictions.

Restrictions can be caused by sequences (not all of the hosts of a prereq 
part of the sequence have been processed) or constraints (the maximum
number of hosts within a tag group are already being updated at the same
time).

A sequence definition like

    sequence:
      - [ $colo.north_america, $colo.south_east_asia ]

will be unrolled to

    prev: $colo.south_east_asia => $colo.north_america

Hosts are arranged in slots:

    colo.north_america:
        - job123-host1
        - job123-host2
        - job123-host3
    colo.south_east_asia:
        - job123-host4
        - job123-host5
        - job123-host6

and when the algorithm iterates over all slots (and eventually all hosts 
within them), it will refuse to add hosts in 
C<colo.south_east_asia> hosts to the run queue as long as there 
are C<colo.north_america> hosts left.

=head1 LICENSE

Copyright (c) 2010-2012 Yahoo! Inc. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
imitations under the License.

=head1 AUTHORS

Mike Schilli <m@perlmeister.com>
Ian Bettinger <ibettinger@yahoo.com>

Many thanks to the following folks for implementing the
original version of Pogo: 

Andrew Sloane <andy@a1k0n.net>, 
Michael Fischer <michael+pogo@dynamine.net>,
Nicholas Harteau <nrh@hep.cat>,
Nick Purvis <nep@noisetu.be>,
Robert Phan <robert.phan@gmail.com>,
Srini Singanallur <ssingan@yahoo.com>,
Yogesh Natarajan <yogesh_ny@yahoo.co.in>
