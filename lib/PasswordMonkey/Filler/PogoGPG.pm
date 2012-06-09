###########################################
package PasswordMonkey::Filler::PogoGPG;
###########################################
use strict;
use warnings;

use base qw(PasswordMonkey::Filler);

###########################################
sub init  {
###########################################
    my($self) = @_;

    $self->{password} = "yes";
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
    return qr{key fingerprint is [a-zA-Z0-9:]+\.[\r\n]+Are you sure you want to continue connecting \(yes/no\)\?\s*};
}

1;

__END__

=head1 NAME

PasswordMonkey::Filler::PogoGPG - PogoGPG 'yes' sayer

=head1 SYNOPSIS

    use PasswordMonkey::Filler::PogoGPG;

=head1 DESCRIPTION

Responds with 'yes' on 

    "key fingerprint is ... Are you sure you want to continue 
     connecting (yes/no)?"

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
