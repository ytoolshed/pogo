###########################################
package Pogo::Scheduler;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Object::Event.pm

###########################################
sub new {
###########################################
    my( $class, %options ) = @_;

    my $self = {
        %options,
    };

    bless $self, $class;

    $self->init();

    return $self;
}

###########################################
sub init {
###########################################
    my( $self ) = @_;

    #$self->reg_cb( "scheduler_" );
}

###########################################
sub task_add {
###########################################
    my( $self, @tasks ) = @_;
}

###########################################
sub run {
###########################################
    my( $self ) = @_;
}

1;

__END__

=head1 NAME

Pogo::Scheduler - Schedule Pogo Jobs or Tasks

=head1 SYNOPSIS

    use Pogo::Scheduler;

    my $s = Pogo::Scheduler->new();

      # add a task
    $s->task_add( ... );

      # run the scheduler
    $s->run();

      # add more tasks
    $s->task_add( ... );

=head1 DESCRIPTION

Pogo::Scheduler is a high-level component that accepts task requests, 
dynamically determines their run order and puts them into a run queue
when their time has come.

Subclasses of Pogo::Scheduler define components running more
complex schedulers, dealing with limited resources or prerequisite 
tasks that have to be completed before their dependents
can start.

Tasks adhere to the Pogo::Scheduler::Task interface. When the scheduler
selects a task to run, it sends it a "task_run" event.

=head2 Configuration

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

    @tagname[ tag_value ]

For example, to refer to all hosts carrying the tag C<colo> with a value
C<north_america>, use C<@colo[north_america]>.

To refer to all hosts carrying a specific tag, regardless of its value,
use the

    @tagname

notation.

=item B<Sequences>

If one host or hostgroup must be finished before the next one in 
a sequence can be started, this dependency can be defined in a sequence:

    sequence:
      - [ @colo[north_america], @colo[south_east_asia] ]

The statement above defines that all hosts carrying the tag C<colo> will be
processed in an order that makes sure that those carrying the tag value
C<north_america> will be finished before any of the hosts carrying the C<colo>
tag value C<south_east_asia> will be started.

=item B<Constraints>

To limit the number of hosts handled in parallel, constraints can be put in
place. For example, 

    constraint:
      @colo[north_america]: 3
      @colo[south_east_asia]: 15%

limits the number of hosts processed in parallel in the C<north_america> 
colocation to 3, and in the C<south_east_asia> colo to 15%. To apply a 
constraint evenly on all hosts carrying a specific tag, grouped by tag value,
use

    constraint:
      @colo: 3

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
      - [ @colo[north_america], @colo[south_east_asia] ] 

    constraint:
      @colo: 2

Now if you ask Pogo to process all hosts carrying the C<@colo> tag (or
specify C<host[1-4]>), the following will happen ("|" indicates that the
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
in any hosts from colo C<south_east_asia> yet, because of the sequence definition
that says that colo C<north_america> has to be completed first. As soon as
host1 and host2 are done, Pogo starts host3, maximizing the resource constraint
of 2 hosts per colo. Even when host2 is done, it cannot proceed with any
colo C<south_east_asia> hosts yet, because of the earlier sequence requirement.
Only when host3 is completed, it starts both host4 and host5 in parallel, 
again maximizing the per-colo resource constraint of 2.

=head2 Combining Tags

Tags can be combined using a boolean AND by nesting them. If an entry
doesn't refer to a value but an underlying key-value structure, the
Pogo configuration will apply the setting to all targets matching the
chain of tags that leads to an eventual value.

For example, if a constraint applies to all hosts tagged @frontend in colo
C<north_america>, use

    constraint:
      @frontend:
         @colo[north_america]: 2

=head2 External Tag Resolvers

In your organization, you might have custom rules on how to 'tag' hosts or
combine them into groups. This is why the Pogo configuration format supports
I<custom tag resolvers>, a plugin system that allows you to add customized 
logic.

If a tag cannot be resolved into a list of targets, the configurator will
look try to load a Plugin with the tag's name.

For example, with

    constraint:
      @_MyRules[my_db_server]: 2

and no tag C<_MyRules> defined anywhere in the configuration file, the
scheduler will look for C<MyRules.pm> in

    lib/Pogo/Scheduler/Config/Plugin

and call its C<targets()> method with a parameter of C<my_db_server> 
to obtain all targets in the 'my_db_server' group.

=head2 Slot Algorithm

To determine runnable hosts and put them onto the run queue, the algorithm
needs to iterate over all not yet active hosts of a job, and evaluate
for each if adding it would violate one of the predefined restrictions.

According to the tag definitions, hosts carry one or more tags with
corresponding values. 

A sequence definition like

    sequence:
      - [ @colo[north_america], @colo[south_east_asia] ] 

will be unrolled to

    prev: colo.north_america => colo.south_east_asia

by concatenating the components in alphabetical order. Hosts are arranged
in slots:

    colo.north_america:
        - job123-host1
        - job123-host2
        - job123-host3
    colo.south_east_asia:
        - job123-host4
        - job123-host5
        - job123-host6

and when the algorithm iterates over all slots (and eventually all hosts 
within them), it will refuse to add C<colo.south_east_asia> hosts to the run 
queue as long as there are C<colo.north_america> hosts left.

TODO

=head1 IMPLEMENTATION

=head2 ZooKeeper Layout

    /pogo/global/resource/<namespace>
    /pogo/job

To obtain a ticket for a resource, the client to add a sequential node to
the /pogo/resource hierarchy. A resource 

For example if a number of hosts have the tag C<colo> set to either
C<east> or C<west>, 

    tags:
      colo:
        east:
          - @frontend
        west::
          - host5
          - host6

    constraints:
      sequences:
          frontends:
            - host1
            - host2
        

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

=head2 Legacy implementation:

Namespace-level appgroup and constraints definitions in a yaml configuration
file:

    <namespace>.yml

    appgroups:
      - <appgroup>:
         - host1
         - host2
    sequences:
      <env_name>:
        - [ foo, bar, baz ]
    constraints:
      <appgroup>:
        <env_name>: 15%

Gets transformed into the following ZooKeeper layout:

    /pogo/ns/<namespace>
      |- env
        |- <slot_name>
          |- <jobid>_<host1>
          |- <jobid>_<host2>
        |- <slot_name>
          |- <jobid>_<host3>
          |- <jobid>_<host4>
      |- conf/sequences
        |- pred
           |- <env_name>:
             |- foo: bar
             |- bar: baz
        |- succ
           |- <env_name>:
             |- baz: bar
             |- bar: foo

    /pogo/job/<jobid>:
      |- host
        |- <host1>: <status>
          |- _info: ()
        |- <host2>: <status>
          |- _info: ()
        |- <host3>: <status>
          |- _info: ()
        |- <host4>: <status>
          |- _info: ()
      |- slot
        |- <slot1>
          |- <host1>
          |- <host2>
        |- <slot2>
          |- <host3>
          |- <host4>

Where C<slot_name> consists of 
C<"E<lt>appgroupE<gt>_E<lt>env_name<gt>_E<lt>env_valueE<gt>">.

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=back

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
