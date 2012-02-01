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
    shift @{ $self->{ queue } };
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
            } else {
                  # throw item out
                DEBUG "throwing out $item";
                $self->end_current();
                $self->process();
            }


        }
    );

    $self->event( "next", $item);
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

Pogo::Util::QP is a generic in-memory queue processor, somewhat
inspired by Amazon's SQS. 

Items get pushed via the C<"push"> event, and are offered for processing
in a C<"next"> event, which a user of the queue subscribes to.

If an item could be processed successfully, the user sends back an
C<"ack"> event, which causes the queue to issue the next "next" event
with the next item if there is one.

If there is no C<"ack"> within the configurable C<timeout> timeframe, 
the queue will retry the same item by issuing another C<"next"> event.
This continues, until the number of C<retries> is reached, then the
item is thrown away.

=head1 AUTHOR

2012, Mike Schilli <cpan@perlmeister.com>
