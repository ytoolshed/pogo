###########################################
package Pogo::Util::SSH::Agent;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Object::AnyEvent;
use AnyEvent;

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        %options,
    };

    bless $self, $class;
}

###########################################
sub start {
###########################################
    my( $self ) = @_;

    # SSH_AUTH_SOCK=$SSH_AUTH_SOCK ; echo SSH_AGENT_PID=$SSH_AGENT_PID ; ';
}

###########################################
sub key_add {
###########################################
    my( $self, $key ) = @_;

}

1;

__END__

=head1 NAME

Pogo::Util::SSH::Agent - Start ssh-agent and add keys to it

=head1 SYNOPSIS

    use Pogo::Util::SSH::Agent;

    my $agent = Pogo::Util::SSH::Agent->new();

    $agent->start( sub {
        my( $auth_sock, $agent_pid ) = @_;

        # ...
    } );

    $agent->key_add( $private_key, sub {
        my( $rc ) = @_;

        # ...
    } );

    $agent->shutdown();

=head1 DESCRIPTION

Pogo::Util::SSH::Agent is an AnyEvent component for starting an ssh-agent
process and feeding private keys to it. It will provide the ssh auth
socket the agent is listening on, which can be used later when invoking
the C<ssh> command, which will look in an environment variable name
C<$SSH_AUTH_SOCK> for the unix socket file path.

=head1 METHODS

=over 4

=item C<new()>

Constructor.

=item C<auth_socket()>

Set/get the auth socket the agent is listening on.

=item C<start()>

Starts the ssh-agent process.

=item C<key_add( $key_string )>

Adds an ssh private key to the agent without writing it to disk.
Employs some crazy fifo logic to accomplish this.

=item C<shutdown()>

Shuts down the ssh-agent process.

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

