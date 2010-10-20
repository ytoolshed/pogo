package Pogo::API::V3;

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

use strict;
use warnings;

use Log::Log4perl qw(:easy);
use Sys::Hostname qw(hostname);

use Pogo::Engine;

our $instance;

sub init
{
  my $class = shift;
  my $self = {
    hostname => hostname(),
  };

  return bless $self, $class;
}

sub instance
{
  my ($class, %opts) = @_;
  $instance ||= $class->init(%opts);
  return $instance;
}

# all rpc methods return an arrayref
sub _rpc_ping
{
  return [ Pogo::Engine->ping, @_ ];
}

sub _rpc_err
{
  LOGDIE "@_";
}

sub rpc
{
  my ($self, $action, @args) = @_;
  my $response = Pogo::API::V3::Response->new();

  my $method = '_rpc_' . $action;

  if (!$self->can($method))
  {
    ERROR "no such method $action";
    $response->set_error("No such action $action");
    return $response;
  }

  $response->add_header( action => $action );
  my $out = eval { $self->$method(@args); };
  return $out
    if ref $out eq 'Pogo::API::V3::Response';

  if ($@)
  {
    $response->set_error($@);
  }
  else
  {
    $response->set_ok;
    $response->set_records($out);
  }

  return $response;
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

  Andrew Sloane <asloane@yahoo-inc.com>
  Michael Fischer <mfischer@yahoo-inc.com>
  Nicholas Harteau <nrh@yahoo-inc.com>
  Nick Purvis <nep@yahoo-inc.com>
  Robert Phan <rphan@yahoo-inc.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
