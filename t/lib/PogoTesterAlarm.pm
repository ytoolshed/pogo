package PogoTesterAlarm;
use Carp qw( confess );

if( ! defined $DB::OUT ) {
    alarm( 60 );
}

$SIG{ALRM} = sub { confess( @_ ); };

1;

=pod

=head1 NAME

  PogoTesterAlarm

=head1 SYNOPSIS

  use PogoTesterAlarm;

=head1 DESCRIPTION

Sets an alarm(60) but only if we're not running the debugger.

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

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
