package Pogo::Client::GPGSignature;

# Copyright (c) 2010-2011 Yahoo! Inc. All rights reserved.
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

use 5.008;
use common::sense;

use File::Temp qw(tempfile);
use Log::Log4perl qw(:easy);
use GnuPG qw(:algo);

use Pogo::Client::AuthCheck qw(get_password);

use Exporter 'import';
our @EXPORT_OK = qw(create_signature);

sub create_signature
{
  my $opts = shift;

  my $gpg_passphrase;
  #Get the passphrase for the private key
  $gpg_passphrase = get_password("Enter the gpg passphrase to sign $opts->{recipe}: ");

  # if the keyring-userid is not provided
  # default to unix userid
  if ( !defined $opts->{'keyring-userid'} )
  {
    $opts->{'keyring-userid'} = scalar getpwuid($<);
  }

  # Fields that needs to used to generate the gpg signature
  my @used_signature_fields;
  if ( !defined $opts->{'signature_fields'} )
  {
    foreach my $field (qw(command target run_as namespace posthook prehook))
    {
      if ( defined $opts->{$field} )
      {
        push( @used_signature_fields, $field ) if $opts->{$field};
      }
    }
    push( @used_signature_fields, 'signature_fields' )
      if (@used_signature_fields);
    @used_signature_fields = sort @used_signature_fields;
    $opts->{'signature_fields'} = \@used_signature_fields;
  }

  my $serialized_data;
  foreach my $field ( @{ $opts->{'signature_fields'} } )
  {
    next unless ( defined $opts->{$field} );
    if ( ( $field eq 'signature_fields' ) || ( $field eq 'target' ) )
    {
      $serialized_data .= $field . 0x01 . join( ';', @{ $opts->{$field} } );
    }
    else { $serialized_data .= $field . 0x01 . $opts->{$field}; }
  }

  my $data_file = File::Temp->new();
  $data_file->print($serialized_data);
  close $data_file;

  my $signature_file = File::Temp->new();
  close $signature_file;

  if ( !defined $opts->{'keyring-dir'} )
  {
    LOGDIE "No gnupg home directory found"
      unless ( -e $ENV{"HOME"} . "/.gnupg" );
    $opts->{'keyring-dir'} = $ENV{"HOME"} . "/.gnupg";
  }

  my $gpg = new GnuPG( homedir => $opts->{'keyring-dir'} );
  eval {
    $gpg->sign(
      plaintext     => $data_file->filename,
      output        => $signature_file->filename,
      armor         => 1,
      "local-user"  => $opts->{'keyring-userid'},
      passphrase    => $gpg_passphrase,
      "detach-sign" => 1,
    );
  };
  if ($@)
  {
    LOGDIE "Creating signature failed: $@\n";
  }

  open( my $signature_fh, $signature_file->filename )
    or LOGDIE "Unable to open file: $!\n";
  local $/;
  my $signature_data = <$signature_fh>;

  my %signature = (
    name => $opts->{'keyring-userid'},
    sig  => $signature_data,
  );

  INFO "Signature created for recipe $opts->{recipe} by user: " . $opts->{'keyring-userid'};

  return %signature;
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
