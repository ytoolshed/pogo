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

use common::sense;

use AnyEvent::Handle;
use Socket qw(AF_INET inet_aton);
use Log::Log4perl qw(:easy);

use Pogo::Engine;
use Pogo::Engine::Response;
use Pogo::Dispatcher::AuthStore;

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
  run           => 1,
  stats         => 1,
  add_task      => 1,
);

sub accept_handler
{
  my $class = shift;

  # This is the accept callback handler for the user interface to the
  # dispatcher.

  # Here we act like a constructor.  (We have no choice but to place
  # that functionality here, as AnyEvent::Socket only lets us specify
  # a code ref as an accept handler, and not a module name.)

  return sub {
    my ( $fh, $remote_ip, $remote_port ) = @_;
    my $self = {
      remote_ip   => $remote_ip,
      remote_port => $remote_port,
      handle      => undef,
      remote_host => undef,
    };

    bless( $self, $class );

    #DEBUG "rpc connection from " . $self->id;

    my $on_json;
    $on_json = sub {
      my ( $h,   $req )  = @_;
      my ( $cmd, @args ) = @$req;

      # $cmd is either store or expire

      DEBUG "rpc '$cmd' from " . $self->id;
      if ( !exists $ALLOWED_RPC_METHODS{$cmd} )
      {
        ERROR "unknown command '$cmd' from " . $self->id;
        my $resp = new Pogo::Engine::Response;    # we're gonna fake it here.
        $resp->set_error("unknown rpc command '$cmd'");
        $h->push_write( json => $resp->unblessed );
        $h->push_read( json => $on_json );
        return;
      }

      # presumably we have something valid here
      my $resp;
      eval { $resp = Pogo::Engine->$cmd(@args) };
      if ($@)
      {
        ERROR "command '$cmd' from " . $self->id . "failed";
        $resp = new Pogo::Engine::Response;    # overwrite old possibly-bogus response
        $resp->set_error("internal error: $@");
        $h->push_write( json => $resp->unblessed );
        $h->push_read( json => $on_json );
        return;
      }

      $h->push_write( json => $resp->unblessed );
      $h->push_read( json => $on_json );
      return;
    };

    $self->{handle} = AnyEvent::Handle->new(
      fh       => $fh,
      tls      => 'accept',
      tls_ctx  => Pogo::Dispatcher->instance->ssl_ctx,
      on_error => sub {
        my $fatal = $_[1];
        ERROR sprintf( "%s error reported while talking rpc to %s: $!",
          $fatal ? 'fatal' : 'non-fatal', $self->id );
        undef $self->{handle};

      },
      on_eof => sub {
        INFO "rpc connection closed from " . $self->id;
        undef $self->{handle};
      },
      on_read => sub { },
    );

    $self->{handle}->push_read( json => $on_json );
  };
}

sub id
{
  my $self = shift;
  return sprintf '%s:%d', $self->remote_host, $self->{remote_port};
}

sub remote_host
{
  my $self = shift;
  $self->{remote_host} ||= ( gethostbyaddr( inet_aton( $self->{remote_ip} ), AF_INET ) )[0];
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
