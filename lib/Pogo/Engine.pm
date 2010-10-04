package Pogo::Engine;

use strict;
use warnings;

use Log::Log4perl qw(:easy);
our $instance;

use constant VERSION         => 0.2;
use constant PORT            => 7061;
use constant DEFAULT_API_URI => 'http://localhost:4080/pogo/v3';

sub instance
{
  return $instance if defined $instance;

  my ( $class, $opts ) = @_;
  DEBUG "new Pogo::Engine instance";

  $instance = {
    api_uri    => $opts->{api_uri}    || DEFAULT_API_URI,
    client_min => $opts->{client_min} || '0.0.0',
    start_time => time(),
  };

  return bless $instance, $class;
}

# i guess we don't do anything yet.
sub start
{
  return;
}


1;

=pod

=head1 NAME

  Pogo::Engine - interact with the pogo backend

=head1 SYNOPSIS

CODE GOES HERE

=head1 DESCRIPTION

LONG_DESCRIPTION

=head1 METHODS

B<methodexample>

=over 2

methoddescription

=back

=head1 SEE ALSO

L<Pogo::Dispatcher>

=head1 COPYRIGHT

Apache 2.0

=head1 AUTHORS

  Andrew Sloane <asloane@yahoo-inc.com>
  Michael Fischer <mfischer@yahoo-inc.com>
  Nicholas Harteau <nrh@yahoo-inc.com>
  Nick Purvis <nep@yahoo-inc.com>
  Robert Phan <rphan@yahoo-inc.com>

=cut
