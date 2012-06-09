###########################################
package PasswordMonkey::Filler::PogoPassphrase;
###########################################
use strict;
use warnings;
our $VERSION = 0.01;

use base qw(PasswordMonkey::Filler);

###########################################
sub init  {
###########################################
    my($self) = @_;

    $self->dealbreakers([ 
     ["Bad passphrase, try again:" => 255],
    ]);
}

###########################################
sub pre_filler  {
###########################################
    my($self) = @_;

    $self->expect->send_user(" (supplied by pogo-pw)");
}

###########################################
sub prompt  {
###########################################
    return qr(Enter passphrase for .+:\s*);
}

1;

__END__

=head1 NAME

PassphraseMonkey::Filler::PogoPassphrase - Pogo password provider

=head1 SYNOPSIS

    use PasswordMonkey::Filler::PogoPassphrase;

=head1 DESCRIPTION

Just sends the password when prompted with "Enter passphrase for .+:";

This bundle also contains PasswordMonkey::Filler::YinstPkgPassphrase and
PasswordMonkey::Filler::PogoGPG.

=head1 AUTHOR

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
