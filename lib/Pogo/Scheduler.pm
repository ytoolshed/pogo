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

Pogo::Scheduler is a high-level component that accepts tasks and runs 
them.

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

=item *

Hostgroups: combine hosts in named groups and refer to them by group name
later. Example:

    group:
      frontends:
        - host1
        - host2
      backends:
        - host3
        - host4

=item *

Tags: Hosts can be tagged with labels and assigned a value. For example,
host C<host.colo.com> might be tagged with the label C<colo> and assigned
the value C<south_east_asia>. Example:

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

=item *

Sequences: one host or hostgroup must be finished before the next one in 
a sequence can be started

=item *

Limited resources: Define the number of 

=back 

    group:
      frontends:
        - host1
        - host2
      backends:
        - host3
        - host4

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
