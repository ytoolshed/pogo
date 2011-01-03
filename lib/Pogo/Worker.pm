package Pogo::Worker;

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
use common::sense;

use AnyEvent::Socket;
use AnyEvent::TLS;
use AnyEvent;
use Carp;
use JSON qw(encode_json);
use LWP::UserAgent;
use Log::Log4perl qw(:easy);
use Pogo::Worker::Connection;
use Scalar::Util qw(refaddr);
use Sys::Hostname;

use constant DEFAULT_PORT => 9697;

my $instance;

# {{{ run

sub run
{
  my $class = shift;
  $instance = bless( {@_}, $class );

  # Initialize response queue
  $instance->{connections}   = {};
  $instance->{responsequeue} = [];
  my $port = $instance->{dispatcher_port} || DEFAULT_PORT;

  foreach my $host ( @{ $instance->{dispatchers} } )
  {
    INFO sprintf( "Connecting to dispatcher at %s:%d", $host, $port );
    Pogo::Worker::Connection->new(
      host            => $host,
      port            => $port,
      worker_key      => $instance->{worker_key},
      worker_cert     => $instance->{worker_cert},
      dispatcher_cert => $instance->{dispatcher_cert}
    )->run;
  }

  # Start event loop
  AnyEvent->condvar->recv();

  ERROR "Event loop terminated - this should not have happened!";
}

# }}}
# {{{ connection handling

sub add_connection
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  my $conn = $_[1];
  $instance->{connections}->{ refaddr($conn) } = $conn;
}

sub delete_connection
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  my $conn = $_[1];
  delete $instance->{connections}->{ refaddr($conn) };
}

# }}}
# {{{ response queue

sub send_response
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  my ( $class, $msg ) = @_;
  my @k = keys %{ $instance->{connections} };
  if ( !@k )
  {
    DEBUG sprintf( "queuing response: %s", encode_json($msg) );
    push @{ $instance->{responsequeue} }, $msg;
  }
  else
  {

    # send to a dispatcher
    my $n = int( rand( scalar @k ) );
    my $c = $instance->{connections}->{ $k[$n] };
    $c->send_response($msg);
  }
}

sub dequeue_msg
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return unshift @{ $instance->{responsequeue} };
}

# }}}
# {{{ properties

sub instance
{
  return $instance;
}

sub dispatcher_host
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{dispatcher_host};
}

sub dispatcher_port
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{dispatcher_port};
}

sub dispatcher_cert
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{dispatcher_cert};
}

sub worker_cert
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{worker_cert};
}

sub worker_key
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{worker_key};
}

sub exec_helper
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{exec_helper};
}

sub expect_wrapper
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{expect_wrapper};
}

sub dist_server
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{dist_server};
}

sub ssh_options
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return @{ $instance->{ssh_options} };
}

sub scp_options
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return @{ $instance->{scp_options} };
}

sub output_dir
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{static_path};
}

sub output_uri
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{output_uri};
}

sub max_output
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{max_output};
}

sub num_workers
{
  LOGDIE "Worker not initialized yet" unless defined $instance;
  return $instance->{num_workers};
}

# }}}

1;

=pod

=head1 NAME

  Pogo::Worker

=head1 SYNOPSIS

  use Pogo::Worker;
  my $worker = Pogo::Worker->instance;
  $worker->run;

=head1 DESCRIPTION

LONG_DESCRIPTION

=head1 METHODS

B<methodexample>

=over 2

methoddescription

=back

=head1 SEE ALSO

L<Pogo::Dispatcher>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2010, Yahoo! Inc. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

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

__END__

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
