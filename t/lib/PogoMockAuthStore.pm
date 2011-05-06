package PogoMockAuthStore;
package PogoMockAuthStore;

  # Pogo::Dispatcher::AuthStore mockery
my $secstore = Test::MockObject->new();
$secstore->fake_module(
    'Pogo::Dispatcher::AuthStore',
    instance => sub { return $secstore; },
);

$secstore->mock(get => sub {
        my($self, $key) = @_;
        return $self->{store}->{$key};
    });
$secstore->mock(store => sub {
        my($self, $key, $val) = @_;
        $self->{store}->{$key} = $val;
    });

1;

__END__

=head1 NAME

PogoMockAuthStore - A Mock for Pogo::Dispatcher:AuthStore 

=head1 SYNOPSIS

      # in the test script
    use PogoMockAuthStore;

=head1 DESCRIPTION

Pretends to have loaded Pogo::Dispatcher::AuthStore already (so doesn't barf 
in test scripts if Net::ZooKeeper isn't installed). Offers a total bogus 
implementation.

=head1 AUTHOR

2011, Mike Schilli <github@perlmeister.com>
