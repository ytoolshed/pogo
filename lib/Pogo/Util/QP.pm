###########################################
package Pogo::Util::QP;
###########################################
use strict;
use warnings;
use base qw( Object::Event );
use Log::Log4perl qw(:easy);

###########################################
sub new {
###########################################
    my( $class, %options ) = @_;

    my $self = {
        retries   => -1,
        timeout   =>  5,
        queue     => [],
        pending   =>  0,
        cur_retry =>  0,
        %options,
    };

    bless $self, $class;

    $self->init();

    return $self;
}

###########################################
sub init {
###########################################
    my( $self ) = @_;

    $self->reg_cb( "push", sub {
        my( $c, $item ) = @_;

        push @{ $self->{ queue } }, $item;

        if( !$self->{ pending } ) {
            $self->process();
        }
    } );

    $self->reg_cb( "ack", sub {
        my( $c ) = @_;

        DEBUG "ack";

        if( !$self->{ pending } ) {
            LOGWARN "Received out of sequence ACK";
            return;
        }

        $self->end_current();
        $self->process();
    } );
}

###########################################
sub end_current {
###########################################
    my( $self ) = @_;

    $self->{ pending } = 0;
    $self->{ timer }   = undef;

      # take item off queue
    DEBUG "Taking off $self->{ queue }->[0]";
    shift @{ $self->{ queue } };

    if( !scalar @{ $self->{ queue } } ) {
        DEBUG "Issuing idle";
        $self->event( "idle" );
    }
}

###########################################
sub process {
###########################################
    my( $self ) = @_;

    if( !scalar @{ $self->{ queue } } ) {
        return; # no next item
    }

    DEBUG "process $self->{ queue }->[0]";

    $self->{ pending }     = 1;
    $self->{ cur_retries } = $self->{ retries };

    my $item = $self->{ queue }->[0];

    $self->{ timer } = AnyEvent->timer(
        after    => $self->{ timeout },
        interval => $self->{ timeout },
        cb       => sub {
            DEBUG "timeout for item $item";
            DEBUG "cur_retries for item $item: $self->{ cur_retries }";

            if( $self->{ cur_retries } > 0 ) {
                DEBUG "re-issuing $item";
                --$self->{ cur_retries };
                $self->event( "next", $item );
            } elsif( $self->{ cur_retries } < 0 ) {
                DEBUG "re-issuing $item";
                $self->event( "next", $item );
            } else {
                  # throw item out
                DEBUG "throwing out $item";
                $self->end_current();
                $self->process();
            }


        }
    ) if $self->{ timeout } >= 0;

    $self->event( "next", $item);
}

###########################################
sub push {
###########################################
    my( $self, @args ) = @_;

    $self->event( "push", @args );
}

###########################################
sub ack {
###########################################
    my( $self ) = @_;

    $self->event( "ack" );
}

1;

__END__

=head1 NAME

Pogo::Util::QP - Queue Processor

=head1 SYNOPSIS

    use Pogo::Util::QP;

    my $qp = Pogo::Util::QP->new(
        timeout => 3,
        retries => 2,
    );

    $qp->reg_cb( "next", sub {
        my( $c, $item ) = @_;

        if( rand(2) > 1 ) {
            print "Processing $item\n";
            $qp->event( "ack" );
        } else {
            print "Forgetting $item\n";
        }
    } );

    $qp->event( "push", "foo" );
    $qp->event( "push", "bar" );
    $qp->event( "push", "baz" );

=head1 DESCRIPTION

Pogo::Util::QP is a generic in-memory queue manager, somewhat
inspired by Amazon's SQS.

Items get pushed onto the internal queue
via a C<"push"> event, and are offered for processing
in an outgoing C<"next"> event, which a user of the queue manager
subscribes to.

If an item could be processed successfully, the user sends back an
C<"ack"> event, which causes the queue to issue the next "next" event
with the next item if there is one.

If C<Pogo::Util::QP> receives no C<"ack"> within the 
configurable C<timeout> timeframe, the queue will re-emit a C<next>
event for the same item in the hope that this time the user will
process it. This continues, until an C<ack> from the user is received, 
or the number of C<retries> is reached, which is when the item gets 
thrown away.

=head1 METHODS

=over 4

=item C<new>

Constructor. Takes two parameters, C<timeout> and C<retries>:

    my $qp = Pogo::Util::QP->new(
        timeout => 3,
        retries => 2,
    );

If C<retries> is set to C<0>, the manager won't retry an item and will
just throw it out after the time window expires. If C<retries> is set
to a negative value, it will retry indefinitely.

If C<timeout> is set to a positive value, items will be re-tried after
after the configured number of seconds. If C<timeout> is set to C<-1>,
items won't time out and the manager will wait indefinitely for an C<ack>
before offering new items.

=back

=head1 EVENTS (INCOMING)

=over 4

=item C<push [$item]>

User submits item.

=item C<ack>

User signals that item has been processed and should be removed from
the queue.

=back

=head1 EVENTS (OUTGOING)

=over 4

=item C<next [$item]>

New item available for processing.

=back

=head1 AUTHOR

2012, Mike Schilli <cpan@perlmeister.com>
