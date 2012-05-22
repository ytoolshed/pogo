###########################################
package Pogo::Plugin::ZooKeeper::Default;
###########################################
use strict;
use warnings;
use Net::ZooKeeper;
use Exporter qw( import );
our @ISA       = qw( Exporter Net::ZooKeeper );
our @EXPORT_OK = qw( ZOK ZINVALIDSTATE ZCONNECTIONLOSS );

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = { %options, };

    bless $self, $class;
}

###########################################
sub priority {
###########################################
    my ( $self ) = @_;

    return 10;
}

1;

__END__

=head1 NAME

Pogo::Plugin::ZooKeeper::Default - Pogo default ZooKeeper plugin

=head1 SYNOPSIS

    use Pogo::Plugin::ZooKeeper::Default;

=head1 DESCRIPTION

A plugin to load to Net::ZooKeeper.

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

