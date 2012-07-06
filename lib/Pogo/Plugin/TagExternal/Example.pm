###########################################
package Pogo::Plugin::TagExternal::Example;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use Module::Pluggable;

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        %options,
    };

    bless $self, $class;
}

###########################################
sub members {
###########################################
    my ( $self, @params ) = @_;

    my $cb;

    if( ref $params[-1] eq "CODE" ) {
        $cb = pop @params;
    }

      # some test data;
    my @members = qw( foo bar );

      # called asynchronously
    if( defined $cb ) {
        $cb->( \@members );
        return 1;
    }

      # 'blocking' call, return results
    return \@members;
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

Pogo::Scheduler::Config::TagExternal::Plugin::Example - Test plugin

=head1 SYNOPSIS

    use Pogo::Scheduler::Config::TagExternal;
    my $tagex = Pogo::Scheduler::Config::TagExternal->new();

    my $members = $tagex->members( "Example", "bonkgroup" );

=head1 DESCRIPTION

External tag resolver test plugin for Pogo config files.

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

