###########################################
package Pogo::Util::Cache;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;

###########################################
sub new {
###########################################
    my( $class, %options ) = @_;

    my $self = {
        expire => undef,
        timers => { },
        values => { },
        %options,
    };

    bless $self, $class;
}

###########################################
sub set {
###########################################
    my( $self, $key, $value ) = @_;

    if( exists $self->{ timers }->{ $key } ) {
        delete $self->{ timers }->{ $key };
    }

    if( defined $self->{ expire } ) {
        $self->{ timers }->{ $key } = 
            AnyEvent->timer( after => $self->{ expire }, 
                             cb => sub { 
                                 delete $self->{ values }->{ $key };
                             }
            );
    }

    $self->{ values }->{ $key } = $value;
}

###########################################
sub set_if_not_exists {
###########################################
    my( $self, $key, $value ) = @_;

    if( exists $self->{ values }->{ $key } ) {
        return undef;
    }

    $self->set( $key, $value );
}

###########################################
sub get {
###########################################
    my( $self, $key ) = @_;

    if( exists $self->{ values }->{ $key } ) {
        return $self->{ values }->{ $key };
    }

    return undef;
}

1;

__END__

=head1 NAME

Pogo::Util::Cache - Pogo memory cache

=head1 SYNOPSIS

    use Pogo::Util::Cache;

    my $cache = Pogo::Util::Cache->new(
        expire => $expire_secs,
    );

    $cache->set( "foo", "bar" );

    my $bar = $cache->get( "foo" );

=head1 DESCRIPTION

Pogo::Util::Cache implements a simple AnyEvent-based memory cache. For
every updated item, it starts an AnyEvent->timer(), whose callback
will destroy the entry when the item expires.

=head1 METHODS

=over 4

=item C<new( expire => $expire_secs )>

Constructor. Expire time of entries is set in seconds. If C<expire> isn't
set or set to C<undef>, items never expire.

=item C<set( key => 'value' )>

Set a cached item. The item can have any value except 'undef' (otherwise
you won't be able to distinguish if it has been set or not).

=item C<get( "key" )>

Returns the previously set cached item or C<undef> if the item hasn't
been set or has expired.

=item C<set_if_not_exists( key => 'value' )>

Checks if the item exists in the cache and sets it to the new value
if it doesn't exist already in one atomic transaction.

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

