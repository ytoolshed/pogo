###########################################
package Pogo::Client::Util;
###########################################
use strict;
use warnings;
require Exporter;
our @EXPORT_OK = qw( password_encrypt );
our @ISA = qw( Exporter );
use Log::Log4perl qw(:easy);
use Crypt::OpenSSL::RSA;
use Crypt::OpenSSL::X509;
use MIME::Base64 qw(encode_base64);
use File::Temp qw( tempfile );
use Sysadm::Install qw( :all );

###########################################
sub password_encrypt {
###########################################
  my( $worker_crt, $password ) = @_;

  Crypt::OpenSSL::RSA->import_random_seed();

  if( ref $worker_crt and
      ref $worker_crt eq "SCALAR" ) {

      my( $fh, $tempfile ) = tempfile( UNLINK => 1 );
      blurt $$worker_crt, $tempfile;
      $worker_crt = $tempfile;
  }

  if( !-f $worker_crt ) {
      die "Worker cert not found: No such file $worker_crt";
  }

  my $x509 = Crypt::OpenSSL::X509->new_from_file( $worker_crt );
  my $rsa_pub = Crypt::OpenSSL::RSA->new_public_key( $x509->pubkey() );

  return encode_base64( $rsa_pub->encrypt( $password ) );
}

1;

__END__

=head1 NAME

Pogo::Client::Util - Pogo client utilities

=head1 DESCRIPTION

A collection of utilities for the Pogo command line client.

=head1 LICENSE

Copyright (c) 2010-2012 Yahoo! Inc. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
imitations under the License.

=head1 AUTHORS

Mike Schilli <m@perlmeister.com>
Ian Bettinger <ibettinger@yahoo.com>

Many thanks to the following folks for implementing the
original version of Pogo: 

Andrew Sloane <andy@a1k0n.net>, 
Michael Fischer <michael+pogo@dynamine.net>,
Nicholas Harteau <nrh@hep.cat>,
Nick Purvis <nep@noisetu.be>,
Robert Phan <robert.phan@gmail.com>,
Srini Singanallur <ssingan@yahoo.com>,
Yogesh Natarajan <yogesh_ny@yahoo.co.in>

