use warnings;
use strict;

use Test::More qw(no_plan);
BEGIN { use_ok('Pogo') };

ok(1);
like("123", qr/^\d+$/);
