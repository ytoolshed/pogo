package Pogo::Client::AuthCheck;

# Copyright (c) 2010, Yahoo! Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use common::sense;

# we'll eval() this later in case it's not available/not functional
#use Authen::PAM;

use Log::Log4perl qw/:easy/;
use POSIX qw(ttyname);
use Term::ReadKey qw(ReadMode ReadLine);

use Exporter 'import';

our @EXPORT_OK = qw(get_password check_password);

sub get_password
{
  my $prompt = shift || 'Password: ';

  print $prompt;
  ReadMode('noecho');
  my $pw = ReadLine(0);
  ReadMode('normal');
  print "\n";
  chomp($pw);

  return $pw;
}

sub check_password
{
  my $user   = shift || scalar getpwuid($<);
  my $passwd = shift || get_password();

  my $pamh;
  my $r;

  my $pam_conv = sub {
    my @res;

    while (@_)
    {
      my $code = shift;
      my $msg  = shift;
      my $ans  = '';

      $ans = $user   if ( $code == Authen::PAM::PAM_PROMPT_ECHO_ON() );
      $ans = $passwd if ( $code == Authen::PAM::PAM_PROMPT_ECHO_OFF() );

      push @res, ( Authen::PAM::PAM_SUCCESS(), $ans );
    }
    push @res, Authen::PAM::PAM_SUCCESS();
    return @res;
  };

  eval {
    use Authen::PAM;

    ref( $pamh = Authen::PAM->new( 'login', $user, $pam_conv ) ) || die;
  };

  if ($@)
  {
    LOGDIE "Password checking not available; set 'check_password: 0' in your .pogoconf to skip\n";
  }

  $r = $pamh->pam_set_item( Authen::PAM::PAM_TTY(), ttyname( fileno(STDIN) ) );
  $r = $pamh->pam_authenticate;

  if ( $r == Authen::PAM::PAM_SUCCESS() )
  {
    return 1;
  }

  # fail
  return;
}

1;

=pod

=head1 NAME

  CLASSNAME - SHORT DESCRIPTION

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

  Andrew Sloane <andy@a1k0n.net>
  Michael Fischer <michael+pogo@dynamine.net>
  Mike Schilli <m@perlmeister.com>
  Nicholas Harteau <nrh@hep.cat>
  Nick Purvis <nep@noisetu.be>
  Robert Phan <robert.phan@gmail.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
