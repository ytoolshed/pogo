package Pogo::Dispatcher::AuthStore;

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

use Data::Dumper;

use 5.008;
use common::sense;

use Socket qw(inet_ntoa);
use AnyEvent::Socket qw(tcp_server tcp_connect);
use AnyEvent::TLS;
use Log::Log4perl qw(:easy);
use Sys::Hostname qw(hostname);

use constant DEFAULT_PORT => 9698;

# {{{ constructors

my $instance;

sub instance
{
  return $instance;
}

sub init
{
  my ( $class, $conf ) = @_;

  if ( !defined $conf->{peers} or !scalar @{ $conf->{peers} } )
  {
    WARN "Authstore peer list not configured.  Not storing secrets.";
    $instance = bless { secrets => {} }, $class;
    return;
  }

  my %peers = map { _resolve_host($_) => $_ } @{ $conf->{peers} };

  # seppuku
  delete $peers{ _resolve_host(hostname) };
  delete $peers{ _resolve_host('localhost') };

  $instance = bless(
    { peers   => \%peers,
      secrets => {},
      port    => $conf->{rpc_port} || DEFAULT_PORT,
    },
    $class
  );

  #start_server();
  start_client( 0, $_ ) for values %{ $instance->{peers} };
  return $instance;
}

# }}}
# {{{ store

sub store
{
  LOGDIE "Authstore not initialized yet" unless defined $instance;
  my ( $self, $job, $pw, $secrets, $expire ) = @_;

  # stash locally
  _store_local( $job, $pw, $secrets, $expire );

  # store on hosts in the peerlist
  $_->push_write( json => [ 'storesecrets', $job, $pw, $secrets, $expire ] )
    for values %{ $instance->{clients} };
}

sub _store_local
{
  LOGDIE "Authstore not initialized yet" unless defined $instance;

  my ( $job, $pw, $secrets, $expire ) = @_;

  INFO "stored secrets for job $job";
  $instance->{secrets}->{$job} = [ $pw, $secrets, $expire ];

  # start expiration timer
  my $timer;
  $timer = AnyEvent->timer(
    after => $expire - time(),
    cb    => sub {
      INFO "expiring secrets for job $job";
      delete $instance->{secrets}->{$job};
      undef $timer;
    },
  );
}

sub get
{
  my ( undef, $job ) = @_;
  return $instance->{secrets}->{$job};
}

# }}}
# {{{ start_server

sub start_server
{
  LOGDIE "Authstore not initialized yet" unless defined $instance;

  tcp_server(
    $instance->{bind_address},
    $instance->{authstore_port},
    sub {
      my ( $fh, $host, $port ) = @_;
      local *__ANON__ = 'AE:cb:connect_cb';
      INFO "Received connection from authstore peer at $host:$port";

      my $handle;
      $handle = AnyEvent::Handle->new(
        fh      => $fh,
        tls     => 'accept',
        tls_ctx => {
          key_file  => Pogo::Dispatcher->dispatcher_key,
          cert_file => Pogo::Dispatcher->dispatcher_cert,
          ca_file   => Pogo::Dispatcher->dispatcher_cert,
          verify    => 1,
          verify_cb => sub {
            local *__ANON__ = 'AE:cb:verify_cb';
            my $preverify_ok = $_[4];
            my $cert         = $_[6];
            DEBUG sprintf( "certificate: %s", AnyEvent::TLS::certname($cert) );
            return $preverify_ok;
          },
        },
        keepalive   => 1,
        on_starttls => sub {
          local *__ANON__ = 'AE:cb:on_starttls';
          my $success = $_[1];
          my $msg     = $_[2];
          if ($success)
          {
            INFO
              sprintf( "SSL/TLS handshake completed with authstore peer at %s:%d", $host, $port );
          }
          else
          {
            $handle->destroy;
            ERROR sprintf( "Failed to complete SSL/TLS handshake with authstore peer at %s:%d: %s",
              $host, $port, $msg );
          }
        },
        on_eof => sub {
          $handle->destroy;
          ERROR sprintf( "Unexpected EOF received from authstore peer at %s:%d", $host, $port );
        },
        on_error => sub {
          $handle->destroy;
          my $msg = $_[2];
          ERROR sprintf( "I/O error occurred while communicating with authstore peer at %s:%d: %s",
            $host, $port, $msg );
        },
        on_read => sub {
          $handle->push_read(
            json => sub {
              my ( $h,   $req )  = @_;
              my ( $cmd, @args ) = @$req;

              if ( $cmd eq 'store' )
              {
                my ( $jobid, $pw, $secrets, $expire ) = @args;
                DEBUG "got secretss for job $jobid from authstore peer $host:$port";
                _store_local( $jobid, $pw, $secrets, $expire );
              }
              elsif ( $cmd eq 'expire' )
              {
                my ($job) = @args;
                delete $instance->{secrets}->{$job};
              }
              elsif ( $cmd eq 'ping' )
              {
                $h->push_write( json => ['pong'] );
              }
            }
          );
        },
      );
    },
    sub {
      local *__ANON__ = 'AE:cb:prepare_cb';
      INFO "Accepting authstore peer connections on $_[1]:$_[2]";
    },
  );
}

# }}}
# {{{ start_client

# called for each peer
sub start_client
{
  LOGDIE "Authstore not initialized yet" unless defined $instance;

  my ( $interval, $host ) = @_;

  DEBUG sprintf( "Initiating connection to authstore peer %s in %0.2f secs", $host, $interval );
  my $port = $instance->{port};

  my $timer;
  $timer = AnyEvent->timer(
    after => $interval,
    cb    => sub {
      local *__ANON__ = 'AE:cb:timer_cb';
      undef $timer;
      INFO sprintf( "initializing connection to authstore %s:%d", $host, $port );
      my $handle;
      $handle = AnyEvent::Handle->new(
        connect => [ $host, $port ],
        tls     => 'connect',
        tls_ctx => {
          key_file  => Pogo::Dispatcher->dispatcher_key,
          cert_file => Pogo::Dispatcher->dispatcher_cert,
          ca_file   => Pogo::Dispatcher->dispatcher_cert,
          verify    => 1,
          verify_cb => sub {
            local *__ANON__ = 'AE:cb:verify_cb';
            my $preverify_ok = $_[4];
            my $cert         = $_[6];
            DEBUG sprintf( "certificate: %s", AnyEvent::TLS::certname($cert) );
            return $preverify_ok;
          },
        },
        on_connect => sub {
          local *__ANON__ = 'AE:cb:on_connect';
          INFO sprintf( "Connected to authstore peer at %s:%d", $host, $port );
        },
        on_starttls => sub {
          local *__ANON__ = 'AE:cb:on_starttls';
          my $success = $_[1];
          my $msg     = $_[2];
          if ($success)
          {
            INFO
              sprintf( "SSL/TLS handshake completed with authstore peer at %s:%d", $host, $port );
            $instance->{clients}->{$host} = $handle;

            # send over all the goods
            while ( my ( $job, $pwent ) = each %{ $instance->{secrets} } )
            {
              $handle->push_write( json => [ 'store', $job, @$pwent ] );
            }
          }
          else
          {
            $handle->destroy;
            ERROR sprintf( "Failed to complete SSL/TLS handshake with authstore peer at %s:%d: %s",
              $host, $port, $msg );
            start_client( rand(5), $host );
          }
        },
        keepalive => 1,
        no_delay  => 1,
        on_eof    => sub {
          local *__ANON__ = 'AE:cb:on_eof';
          $handle->destroy;
          ERROR sprintf( "Unexpected EOF received from authstore peer at %s:%d", $host, $port );
          start_client( rand(5), $host );
        },
        on_error => sub {
          local *__ANON__ = 'AE:cb:on_error';
          my $msg = $_[2];
          $handle->destroy;
          ERROR sprintf( "I/O error occurred while communicating with authstore peer at %s:%d: %s",
            $host, $port, $msg );
          start_client( rand(5), $host );
        },
      );
    }
  );
}

# }}}
# {{{ misc

sub _resolve_host
{
  return inet_ntoa( ( gethostbyname( $_[0] ) )[4] );
}

# }}}

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
