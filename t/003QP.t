
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/lib";

use Test::More;
use Log::Log4perl qw(:easy);

# Log::Log4perl->easy_init({ level => $DEBUG, layout => "%F{1}-%L: %m%n" });

use Pogo::Util::QP;

plan tests => 5;

###################################

my $cv = AnyEvent->condvar;

my $qp = Pogo::Util::QP->new(
    timeout => 1,
    retries => 1,
);

$qp->reg_cb( "next", sub {
        my( $c, $item ) = @_;

        is $item, "foo", "next item foo";

            # 'forget' to ack
    } );

$qp->reg_cb( "idle", sub {
    ok 1, "queue empty";
    $cv->send();
} );

$qp->event( "push", "foo" );

$cv->recv();

###################################

$qp = Pogo::Util::QP->new(
    timeout => 1,
    retries => 1,
);

my $cbs = 0;

$qp->reg_cb( "next", sub {
        my( $c, $item ) = @_;

        $cbs++;
        $qp->event( "ack" );
    } );

$qp->reg_cb( "idle", sub {
    ok 1, "queue empty";
    is $cbs, 1, "only 1 callback";
    $cv->send();
} );

$qp->event( "push", "bar" );

$cv->recv();
