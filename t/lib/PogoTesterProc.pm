package PogoTesterProc;

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

use Log::Log4perl qw(:easy);
use Proc::Simple;
use IO::Handle;

sub new
{
  my ( $class, $name, @args ) = @_;
  my $self = {
    name => $name,
    args => \@args,
  };
  return ( bless( $self, $class ) );
}

sub name { return shift->{name} }
sub args { return @{ shift->{args} } }

sub stderr_log_path
{
  my $self = shift;
  return "/tmp/$self->{name}.stderr.log";
}

sub stdout_log_path
{
  my $self = shift;
  return "/tmp/$self->{name}.stdout.log";
}

sub start
{
  my $self = shift;

  my $proc = $self->{proc} = Proc::Simple->new();

  open( my $oldout, '>&STDOUT' );
  open( my $olderr, '>&STDERR' );

  open( STDOUT, '>' . $self->stdout_log_path );
  open( STDERR, '>' . $self->stderr_log_path );

  $proc->kill_on_destroy(1) unless $ENV{POGO_PERSIST};
  DEBUG "Starting $self->{name}";
  $proc->start( @{ $self->{args} } );

  close(STDOUT);
  open( STDOUT, '>&' . $oldout->fileno() );

  close(STDERR);
  open( STDERR, '>&' . $olderr->fileno() );

  return $proc;
}

1;

__END__

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
