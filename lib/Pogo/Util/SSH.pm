###########################################
package Pogo::Util::SSH;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Object::AnyEvent;

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
sub run {
###########################################
    my( $self, $cmd, $cb ) = @_;

}

1;

__END__

=head1 NAME

Pogo::Util::SSH - Component for ssh/ssh-agent usage

=head1 SYNOPSIS

    use Pogo::Util::SSH;

    my $ssh = Pogo::Util::SSH->new();

    $ssh->run( $cmd, sub {
       my( $c, $rc ) = @_;

       if( $rc == 0 ) {
          # success!
       }
    } );

=head1 DESCRIPTION

Pogo::Util::SSH is an AnyEvent component for running commands on 
remote hosts via ssh. 

For authentication, it supports private/public keys.

When private/public keys are used for authentication on the target host,
the component will start up an instance of ssh-agent and feed the private
key to it. The subsequently started C<ssh> process will be pointed to the
Unix socket where C<ssh-agent> is listening, and delegate the key 
challenges by the remote to the agent.

Private keys and key passphrases are I<always> stored in volatile
memory only, I<never> on disk.

=head1 METHODS

=over 4

=item C<new()>

Constructor. Optionally takes a private key string:

    my $ssh = Pogo::Util::SSH->new(
      private_key => "XXX",
      public_key  => "YYY",
      private_key_passphrase => "ZZZ",
    );

=item C<run( $cmd, $cb )>

Run the command $cmd on the target and call the callback C<$cb> when it's
done. The callback is called 

    sub callback {
        my( $c, $rc ) = @_;
        # ...
    }

where C<$rc> is the return code of the ssh command.

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

