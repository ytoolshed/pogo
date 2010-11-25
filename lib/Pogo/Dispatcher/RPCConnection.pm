package Pogo::Dispatcher::RPCConnection;

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

use AnyEvent::Handle;
use Socket qw(AF_INET inet_aton);
use Log::Log4perl qw(:easy);

use Pogo::Engine;
use Pogo::Engine::Response;
use Pogo::Dispatcher::AuthStore;

use constant DEFAULT_PORT => 9696;

our %ALLOWED_RPC_METHODS = (
  err           => 1,
  globalstatus  => 1,
  hostinfo      => 1,
  hostlog_url   => 1,
  jobalter      => 1,
  jobhalt       => 1,
  jobhoststatus => 1,
  jobinfo       => 1,
  joblog        => 1,
  jobresume     => 1,
  jobretry      => 1,
  jobskip       => 1,
  jobsnapshot   => 1,
  jobstatus     => 1,
  lastjob       => 1,
  listjobs      => 1,
  loadconf      => 1,
  ping          => 1,
#  run           => 1,
  stats         => 1,
  add_task      => 1,
);

sub accept
{
  my ( $class, $fh, $host, $port )  = @_;

  my $self = {
    fh => $fh,
    host => $host,
    port => $port,
  };

  bless( $self, $class );

  $self->{handle} = AnyEvent::Handle->new(
    fh      => $fh,
    tls     => 'accept',
    tls_ctx => {
      key_file => Pogo::Dispatcher->dispatcher_key,
      cert_file => Pogo::Dispatcher->dispatcher_cert,
    },
    on_connect => sub {
      local *__ANON__ = 'AE:cb:on_connect';
      INFO sprintf("Received RPC connection from %s:%d", $host, $port);
    },
    on_eof  => sub {
      local *__ANON__ = 'AE:cb:on_eof';
      $self->{handle}->destroy;
      ERROR sprintf("EOF received from RPC client at %s:%d", $host, $port);
    },
    on_error => sub {
      local *__ANON__ = 'AE:cb:on_error';
      my $msg = $_[2];
      $self->{handle}->destroy;
      ERROR sprintf( "I/O error occurred while communicating with RPC client at %s:%d: %s", $host, $port, $msg);
    },
    on_read => sub {
      local *__ANON__ = 'AE:cb:on_read';
      $self->{handle}->push_read(json => sub {
        my ( $h,   $req )  = @_;
        my ( $cmd, @args ) = @$req;
        local *__ANON__ = 'AE:cb:on_read:push_read';

        # $cmd is either store or expire

        DEBUG "rpc '$cmd' from " . $self->id;
        if ( !exists $ALLOWED_RPC_METHODS{$cmd} )
        {
          ERROR "unknown command '$cmd' from " . $self->id;
          my $resp = Pogo::Engine::Response->new;    # we're gonna fake it here.
          $resp->set_error("unknown rpc command '$cmd'");
          $h->push_write( json => $resp->unblessed );
          return;
        }

        # presumably we have something valid here
        my $resp;
        eval { $resp = Pogo::Engine->$cmd(@args) };
        if ($@)
        {
          ERROR "command '$cmd' from " . $self->id . "failed";
          $resp = Pogo::Engine::Response->new;    # overwrite old possibly-bogus response
          $resp->set_error("internal error: $@");
          $h->push_write( json => $resp->unblessed );
          return;
        }
        $h->push_write( json => $resp->unblessed );
      });
    },
  );

  return $self;
}

sub id
{
  my $self = shift;
  return sprintf '%s:%d', $self->remote_host, $self->{port};
}

sub remote_host
{
  my $self = shift;
  $self->{remote_host} ||= ( gethostbyaddr( inet_aton( $self->{host} ), AF_INET ) )[0];
  return $self->{remote_host};
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
