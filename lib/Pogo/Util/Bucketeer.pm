###########################################
package Pogo::Util::Bucketeer;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
       buckets           => [],
       bucket_id_current => undef,
       %options,
    };

    bless $self, $class;

      # transform into bucket hashes
    for my $bucket ( @{ $self->{ buckets } } ) {
        $bucket = { map { $_ => 1 } @$bucket };
    }

    $self->bucket_current_next();

    return $self;
}

###########################################
sub bucket_current_next {
###########################################
    my( $self ) = @_;
 
    my $next_bucket = 0;
 
    if( defined $self->{ bucket_id_current } ) {
        $next_bucket = $self->{ bucket_id_current } + 1;
    }
 
    return $self->bucket_current_id( $next_bucket );
}

###########################################
sub bucket_current_id {
###########################################
    my( $self, $id ) = @_;
 
    if( $id < scalar @{ $self->{ buckets } } ) {
        $self->{ bucket_id_current } = $id;
        DEBUG "Setting current bucket id to $id";
        return 1;
    } else {
        DEBUG "Out of buckets, can't increase id to $id";
    }
 
    return undef;
}

###########################################
sub all_done {
###########################################
    my( $self ) = @_;
 
    if( defined $self->{ bucket_id_current } and
        0 == scalar keys %{ 
            $self->{ buckets }->[ $self->{ bucket_id_current } ] } and
        $self->{ bucket_id_current } + 1 == scalar @{ $self->{ buckets } } ) {
        return 1;
    }
 
    return 0;
}

###########################################
sub items {
###########################################
    my( $self ) = @_;
 
    my @items = ();
 
    for my $bucket ( @{ $self->{ buckets } } ) {
        push @items, sort keys %$bucket,
    }
 
    return @items;
}

###########################################
sub item {
###########################################
    my( $self, $item ) = @_;
 
    if( ! defined $self->{ bucket_id_current } ) {
        ERROR "No bucket defined, but got item $item";
        return undef;
    }
 
    if( delete
        $self->{ buckets }->[ $self->{ bucket_id_current } ]->{ $item } ) {
        DEBUG "Item $item came in as expected";
    } else {
        return undef;
    }

      # current bucket empty?
    my $remaining = scalar keys %{
                    $self->{ buckets }->[ $self->{ bucket_id_current } ] };

    if( 0 == $remaining ) {
          # switch to next
        DEBUG "Switching to next bucket";
        $self->bucket_current_next();
    } else {
        DEBUG "$remaining items remaining in bucket";
    }

    return 1;
}

###########################################
package Pogo::Util::Bucketeer::Threaded;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
       threads => [],
       %options,
    };

    bless $self, $class;
}

###########################################
sub bucketeer_add {
###########################################
    my( $self, $bucketeer ) = @_;

    push @{ $self->{ threads } }, $bucketeer;
}

###########################################
sub item {
###########################################
    my( $self, $item ) = @_;

    for my $thread ( @{ $self->{ threads } } ) {
        if( $thread->item( $item ) ) {
            return 1;
        }
    }

    ERROR "None of the threads waiting on item $item";
    return 0;
}

###########################################
sub all_done {
###########################################
    my( $self ) = @_;

    for my $thread ( @{ $self->{ threads } } ) {
        DEBUG "Checking thread $thread";

        if( !$thread->all_done() ) {
            return 0;
        }
    }

      # all threads are done
    return 1;
}

1;

__END__

=head1 NAME

Pogo::Util::Bucketeer - Pogo Test Utility to make sure sequencing works

=head1 SYNOPSIS

    use Pogo::Util::Bucketeer;

    my $bkt = Pogo::Util::Bucketeer->new(
        buckets => [
          [ qw( host1 host2 host3 ),
            qw( host3 host4 ),
          ]
        ]
    );

    $bkt->item( "host2" ) or die;   # ok
    $bkt->item( "host1" ) or die;   # ok

    $bkt->item( "host4" ) or die;   # not ok

    $bkt->item( "host3" ) or die;   # ok
    $bkt->item( "host4" ) or die;   # ok
    $bkt->all_done() or die;        # ok

=head1 DESCRIPTION

Pogo::Util::Bucketeer makes sure a sequencing algorithm spits out 
items in the desired order. It defines N buckets of items.
Within a bucket, the item order is irrelevant. However, items within
a bucket must come out of the sequencer I<before> items of the next bucket
(or any other bucket for that matter).

=head1 EXAMPLE

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

