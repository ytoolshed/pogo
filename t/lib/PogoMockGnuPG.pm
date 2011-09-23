package PogoMockGnuPG;

use File::Temp qw(tempfile);
use Test::MockObject;
use Data::Dumper;

my $mock = Test::MockObject->new();
$mock->fake_module('GnuPG',
                    new => sub { return $mock }
                   );
$mock->mock('sign' => \&mock_sign );

sub mock_sign
{
    my $class = shift;
    my $opts = { @_ };

    open (my $fh, ">", $opts->{output})
        or die "unable to open file: $!\n";
    $fh->print("batman approves this signature");
    close $fh;
}

1;
