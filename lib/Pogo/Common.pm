package Pogo::Common;

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

use 5.008;
use Exporter 'import';
use LWP::UserAgent qw();
use Log::Log4perl qw(:easy);
use YAML::XS qw();
use URI;
use URI::file;

our $PREFIX    = '/usr/local';
our $VERSION   = '4.0';
our $USERAGENT = LWP::UserAgent->new(
  timeout => 65,
  agent   => "Pogo/$VERSION",
);

our $CONFIGDIR = '/Users/nrh/projects/pogo/t/conf/';

#our $CONFIGDIR = '/usr/local/etc/pogo/';
our $WORKER_CERT = "$CONFIGDIR/worker.cert";

our %EXPORT_TAGS = ( vars => [ $VERSION, $POGO_BASE ] );
our @EXPORT_OK = qw($VERSION $POGO_BASE fetch_yaml uri_to_absuri merge_hash);

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

sub fetch_yaml
{
  my $uri = uri_to_absuri(@_);

  my $r;
  eval { $r = $USERAGENT->get($uri); };
  if ($@)
  {
    LOGDIE "Couldn't fetch uri '$uri': $@\n";
  }

  my $yaml;
  if ( $r->is_success )
  {
    $yaml = $r->content;
  }
  else
  {
    LOGDIE "Couldn't fetch uri '$uri': " . $r->status_line . "\n";
  }

  my @data;
  eval { @data = YAML::XS::Load($yaml); };
  if ($@)
  {
    LOGDIE "couldn't parse '$uri': $@\n";
  }

  DEBUG sprintf "Loaded %s records from '$uri'", scalar @data;

  if ( scalar @data == 1 )
  {
    return $data[0];
  }

  return \@data;
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

  Andrew Sloane <asloane@yahoo-inc.com>
  Michael Fischer <mfischer@yahoo-inc.com>
  Nicholas Harteau <nrh@yahoo-inc.com>
  Nick Purvis <nep@yahoo-inc.com>
  Robert Phan <rphan@yahoo-inc.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
