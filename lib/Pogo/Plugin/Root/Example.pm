package Pogo::Plugin::Root::Example;

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

# constructor has to be named new()
sub new { return bless( {}, $_[0] ); }

# mandatory method root_type just returns the name of the type of root
sub root_type { return 'example'; }

# mandatory method transform just returns the transform used to expand a
# 'rootname' and 'command' into a full command to be executed on the host
sub transform
{
  return 'cp ${command} /tmp/${rootname}${command}'
    . ' && sudo chroot /some/special/root/directory/${rootname} --cmd ${command}'
    . ' && rm -f /tmp/${rootname}${command}';
}

# indicates the priority versus other installed root plugins
sub priority { return -1; }

1;

=pod

=head1 NAME

Pogo::Plugin::Root::Example

=head1 SYNOPSIS

    package Pogo::Plugin::Root::MyPlugin;

    sub new { return bless( {}, $_[0] ); }

    sub root_type { return 'myroot'; }

    sub transform { return ''; } # returns your root transform

    sub priority { return 5; }

    1;

=head1 DESCRIPTION

Root plugins allow a Pogo installation to execute commands not only on full routable hosts, but on 
containers (for example chroot-ed environments, BSD jails, or non-routable VMs) within hosts. Pogo refers
to these containers as "roots." The precise motivations and implementation of a given type of 
root at an organization will presumably be clear to that organization.

For installations where this functionality is used, a Pogo root plugin can be written and 
installed in the Pogo::Plugin::Root::* namespace to enable pogo commands to be executed within
your particular implementation of roots.

The key to using Pogo to execute commands within roots is the "transform" for that root type,
which Pogo uses to expand a command and a root name into a full command to be used outside of 
the root, on the host itself. See the description of the C<transform()> method below for details.

Although the Root plugin with the highest priority will be the default root type for the
overall installation, any root plugin that is found at start time can be used in a pogo command. In
addition, each namespace can optionally specify it's own default root type. The order of precedence is: 
client, namespace, global default.

=head1 REQUIRED METHODS

The required methods for a Root plugin are usually very simple. In most cases they will just return
text.

=over 4

=item new():

The constructor for the class has to be named new(). It won't receive any parameters.

=item root_type():

Returns the name of this root type.

=item transform():

Returns the transform used to expand a normal command executed via C<pogo run> into a command that
will be executed within your root type. Two variables will be expanded by Pogo:

=over 4

=item C<${command}>

The full path and name of the pogo-worker-stub which will be copied to the target host.

=item C<${rootname}>

The name of the root.

=back

The command defined by the transform has to do three things:

=over 4

=item 1) Copy the pogo-worker-stub to a path/name that is distinct from other roots. For example: 

    % cp ${command} /tmp/${rootname}${command}

=item 2) Execute the pogo-worker-stub.

=item 3) Remove the pogo-worker-stub copy created in step 1)

    % rm /tmp/${rootname}${command}

=back

For example if you had a set of simple chroot-ed environments in the directory C</var/chroots>, the
full transform for your installation might be:

    cp ${command} /tmp/${rootname}${command} \
    && sudo chroot /var/chroots/${rootname} ${command} \
    && rm -f /tmp/${rootname}${command} \

(more details to be added soon...)

=item priority()

As with other Pogo plugins, this should return the priority so that Pogo::Dispatcher can choose a
default root transform to use.

    sub priority { return 10; }

Unlike most other plugins, *all* installed Root plugins are loaded when the system starts up and
can be used in any given pogo command. See the note above in L<DESCRIPTION>

=back

=head1 USING POGO COMMANDS ON ROOTS

To execute a Pogo command within a root in the most common case, use a hostname:rootname format:

    % pogo-client run -h host.example.com:my_root 'hostname; echo "but inside my_root";'

For more details, please read the pogo-client documentation.

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

