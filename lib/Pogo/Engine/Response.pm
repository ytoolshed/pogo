package Pogo::Engine::Response;

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

use common::sense;

use Carp qw(confess);
use JSON qw(decode_json);
use YAML::XS qw(Dump);
use Log::Log4perl qw(:easy);
use Sys::Hostname qw(hostname);
use Data::Dumper qw(Dumper);

our @EXPORT_CONST = qw(RESPONSE_OK RESPONSE_ERROR RESPONSE_UNKNOWN);
our @EXPORT_OK    = (@EXPORT_CONST);
our %EXPORT_TAGS  = ( const => [@EXPORT_CONST], );

use constant {
  RESPONSE_OK      => 1,
  RESPONSE_ERROR   => 0,
  RESPONSE_UNKNOWN => -1,
};

sub new
{
  my ( $class, $content ) = @_;

  my $self = {
    _format  => 'json',
    _records => [],
  };
  bless $self, $class;

  if ($content)
  {
    $self->load_data($content);
  }
  $self->add_header( hostname => hostname() ) unless $self->has_header('hostname');
  $self->add_header( version => 'V3' );

  return $self;
}

# set_ and add_ records return undef or $self so that we can do chaining on new()

sub load_data
{
  my ( $self, $content ) = @_;
  my $data;
  eval { $data = decode_json($content); };
  if ($@)
  {
    ERROR "Unable to parse content: $@";
    $self->set_error("Unable to parse content: $@");
    return;
  }
  elsif ( scalar @$data != 2 )
  {
    ERROR "Badly-formed response: wrong number of elements";
    DEBUG Dumper $data;
    $self->set_error("Badly-formed response: wrong number of elements");
    return;
  }

  $self->{_header}  = $data->[0];
  $self->{_records} = $data->[1];
  $self->{_state} =
      $data->[0]->{status} eq 'OK'    ? RESPONSE_OK
    : $data->[0]->{status} eq 'ERROR' ? RESPONSE_ERROR
    :                                   RESPONSE_UNKNOWN;
  return 1;
}

# {{{ status

sub is_success
{
  my $self = shift;
  if ( $self->{_state} == RESPONSE_OK )
  {
    return 1;
  }
  return;
}

sub is_error
{
  my $self = shift;
  if ( $self->{_state} == RESPONSE_ERROR )
  {
    return 1;
  }
  return;
}

sub set_ok
{
  my $self = shift;
  $self->{_state} = RESPONSE_OK;
  $self->{_header}->{status} = 'OK';
  return $self;
}

sub set_error
{
  my ( $self, $errmsg ) = @_;

  $self->{_state}            = RESPONSE_ERROR;
  $self->{_header}->{errmsg} = $errmsg;
  $self->{_header}->{status} = 'ERROR';
  return $self;
}

sub status_msg
{
  my $self = shift;
  if ( $self->is_success )
  {
    return $self->{_header}->{status};
  }

  return $self->{_header}->{errmsg};
}

# }}}
# {{{ callback

sub callback
{
  my $self = shift;
  return $self->{_callback};
}

sub is_callback
{
  my $self = shift;
  if ( defined $self->{_callback} && $self->{_callback} ne '' )
  {
    return 1;
  }
  return;
}

sub set_callback
{
  my ( $self, $callback ) = @_;
  if ($callback)
  {
    $self->{_callback} = $callback;
    $self->add_header( response => 'callback' );
    $self->add_header( callback => $callback );
  }
  return $self;
}

# }}} callback
# {{{ pushvar

sub pushvar
{
  my $self = shift;
  return $self->{_pushvar};
}

sub is_pushvar
{
  my $self = shift;
  if ( defined $self->{_pushvar} && $self->{_pushvar} ne '' )
  {
    return 1;
  }
  return;
}

sub set_pushvar
{
  my ( $self, $pushvar ) = @_;
  if ($pushvar)
  {
    $self->{_pushvar} = $pushvar;
    $self->add_header( response => 'pushvar' );
    $self->add_header( pushvar  => $pushvar );
  }
  return $self;
}

# }}} pushvar
# {{{ header

sub header
{
  my $self   = shift;
  my $header = shift;
  if ($header)
  {
    if ( exists $self->{_header}->{$header} )
    {
      return $self->{_header}->{$header};
    }
    else
    {
      return;
    }
  }
  return $self->to_string( $self->{_header} );
}

sub set_header
{
  my ( $self, $data ) = @_;
  $self->{_header} = $data;
  return $self;
}

sub add_header
{
  my ( $self, $key, $value ) = @_;
  $self->{_header}->{$key} = $value;
  return $self;
}

sub has_header
{
  my $self = shift;
  return exists $self->{_header}->{shift};
}

# }}} header
# {{{ records

sub set_records
{
  my ( $self, $data ) = @_;
  $self->{_records} = $data;
  return $self;
}

sub add_record
{
  my ( $self, $data ) = @_;
  push @{ $self->{_records} }, $data;
  return $self;
}

sub records
{
  my $self = shift;
  if ( !defined $self->{_records} || ref $self->{_records} ne 'ARRAY' )
  {
    ERROR "response has no records";
    confess;
    return;
  }
  return @{ $self->{_records} };
}

sub record
{
  my $self = shift;
  if ( ref $self->{_records} eq 'ARRAY' )
  {
    return $self->{_records}->[0];
  }
  return;
}

# }}} records
# {{{ stringify

sub format
{
  my $self = shift;
  return $self->{_format};
}

sub set_format
{
  my ( $self, $format ) = @_;
  if ($format)
  {
    $self->{_format} = lc $format;
  }
  return $self;
}

sub to_string
{
  my ( $self, $data ) = @_;

  my $string;
  if ( $self->format eq 'json' )
  {
    eval { $string = JSON->new->utf8->allow_nonref->encode($data); };
    if ($@)
    {
      ERROR "Error formatting output: $@";
      $self->set_error($@);
      return;
    }
  }
  elsif ( $self->format eq 'json-pretty' )
  {
    eval { $string = JSON->new->utf8->pretty->encode($data); };
    if ($@)
    {
      ERROR "Error formatting output: $@";
      $self->set_error($@);
      return;
    }
  }
  elsif ( $self->format eq 'yaml' )
  {
    eval { $string = Dump($data); };
    if ($@)
    {
      ERROR "Error formatting output: $@";
      $self->set_error($@);
      return;
    }
  }
  else
  {
    ERROR "Unknown format: " . $self->format;
  }

  if ( $self->is_callback )
  {
    $string = $self->callback . '(' . $string . ')';
  }
  elsif ( $self->is_pushvar )
  {
    $string = $self->pushvar . '=' . $string;
  }

  return $string;
}

sub content
{
  my $self = shift;
  return $self->to_string( [ $self->{_header}, $self->{_records} ] );
}

sub unblessed
{
  my $self = shift;
  return [ $self->{_header}, $self->{_records} ];
}

# }}} stringify

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
