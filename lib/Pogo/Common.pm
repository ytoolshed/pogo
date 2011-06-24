package Pogo::Common;

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
use Exporter 'import';
use LWP::UserAgent qw();
use Log::Log4perl qw(:easy);
use URI;
use URI::file;

our $PREFIX    = '/usr/local';
our $VERSION   = '4.0';
our $USERAGENT = LWP::UserAgent->new(
  timeout => 65,
  agent   => "Pogo/$VERSION",
);

our $CONFIGDIR   = '/usr/local/etc/pogo/';
our $WORKER_CERT = "$CONFIGDIR/worker.cert";

our %EXPORT_TAGS = ( vars => [$VERSION] );
our @EXPORT_OK = qw($VERSION uri_to_absuri merge_hash);

sub merge_hash
{
  my ( $onto, $from ) = @_;

  while ( my ( $key, $value ) = each %$from )
  {
    if ( defined $onto->{$key} )
    {
      DEBUG sprintf "Overwriting key '%s' with '%s', was '%s'", $key, $value, $onto->{$key};
    }
    $onto->{$key} = $value;
  }

  return $onto;
}

sub uri_to_absuri
{
  my $rel_uri = shift;
  my $base_uri = shift || $rel_uri;

  $base_uri = URI->new($base_uri);

  if ( !$base_uri->scheme )
  {
    $base_uri = URI::file->new_abs($base_uri);
  }
  my $abs_uri = URI->new_abs( $rel_uri, $base_uri );

  if ( !$abs_uri->scheme )
  {
    $abs_uri = URI::file->new_abs($abs_uri);
  }

  if ( $abs_uri ne $rel_uri )
  {
    DEBUG "converted '$rel_uri' to '$abs_uri'";
  }

  return $abs_uri->as_string;
}

1;

=pod

=head1 NAME

  Pogo::Common

=head1 SYNOPSIS

  use Pogo::Common qw(uri_to_absuri merge_hash);

    # http://foobar.com/blah
  my $absuri = uri_to_absuri("/blah", "http://foobar.com");

    # overwrite $hashref_onto with values from $hashref_from
  merge_hash($hashref_onto, $hashref_from);

=head1 DESCRIPTION

This module exports commonly used functions and constants for internal
use within Pogo.

=head1 COPYRIGHT

Copyright (c) 2010 Yahoo! Inc. All rights reserved.

=head1 LICENSE

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    L<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 AUTHORS

  Andrew Sloane <andy@a1k0n.net>
  Ian Bettinger <ibettinger@yahoo.com>
  Michael Fischer <michael+pogo@dynamine.net>
  Mike Schilli <m@perlmeister.com>
  Nicholas Harteau <nrh@hep.cat>
  Nick Purvis <nep@noisetu.be>
  Robert Phan <robert.phan@gmail.com>
  Srini Singanallur <ssingan@yahoo.com>
  Yogesh Natarajan <yogesh_ny@yahoo.co.in>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
