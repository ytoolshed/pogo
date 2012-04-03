###########################################
package Pogo::Util::Bucketeer;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
       buckets   => [],
       bucket_id => undef,
       %options,
    };

    bless $self, $class;
}

###########################################
sub bucket_current_next {
###########################################
   my( $self ) = @_;

   my $next_bucket = 0;

   if( defined $self->{ bucket_id } ) {
       $next_bucket = $self->{ bucket_id } + 1;
   }

   return $self->bucket_current_id( $next_bucket );
}

###########################################
sub bucket_current_id {
###########################################
   my( $self, $id ) = @_;

   if( $id + 1 < scalar @{ $self->{ buckets } } ) {
       $self->{ bucket_id } = $id;
       return 1;
   }

   return undef;
}

###########################################
sub done {
###########################################
   my( $self ) = @_;

   if( defined $self->{ bucket_id } and
       $self->{ bucket_id } + 1 == scalar @{ $self->{ buckets } } ) {
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
       push @items, @$bucket,
   }
   return @items;
}

###########################################
sub item_finished {
###########################################
   my( $self, $item ) = @_;

   if( ! defined $self->{ bucket_id } ) {


   if( ! defined $self->{ bucket_id } ) {
       die "received unexpected item: $item";
   }
}

1;

__END__

=head1 NAME

Pogo::Util::Bucketeer - Pogo Test Utility to make sure sequencing works

=head1 SYNOPSIS

    use Pogo::Util::Bucketeer;

    my $bkt = Pogo::Util::Bucketeer->new(
        buckets => [
          [ qw( host1 host2 ),
            qw( host3 host4 ),
          ]
        ]
    );

    my $seqr = FooSequencer->new();
    my $cv   = AnyEvent->condvar();

      # Whenever the sequencer spits out an item, we want to check if
      # it's in the bucket order defined earlier or out of sequence.

    $seqr->reg_cb( "foo_item_process", sub {
        my( $c, $item ) = @_;

        if( $bkt->item( $item ) ) {
          print "Item $item received in expected order\n";
        } else {
          die "Whoa! Item $item received in unexpected order!";
        }

        if( $bkt->all_done() ) {
            $cv->send();
        }
    }

      # submit host1, host2, host3, host4 to the sequencer, which then
      # (hopefully) sends them out via events in the bucket order expected
    $seqr->( $bkt->items() );

    $cv->recv();

=head1 DESCRIPTION

Pogo::Util::Bucketeer makes sure a sequencing algorithm spits out 
items in the desired order. It defines N buckets of items.
Within a bucket, the item order is irrelevant. However, items within
a bucket must come out of the sequencer I<before> items of the next bucket
(or any other bucket for that matter).

=head1 EXAMPLE

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

