package Pogo::Dispatcher::AuthStore;

use strict;
use warnings;

use Socket qw(inet_ntoa);
use AnyEvent::Socket qw(tcp_server tcp_connect);
use Log::Log4perl qw(:easy);
use Sys::Hostname;

our $instance;

sub instance
{
  return $instance if defined $instance;
  my ( $class, $conf ) = @_;
  my $peerlist = $conf->{peerlist};

  if ( !defined $peerlist or $peerlist eq '' )
  {
    WARN "peerlist not configured, not storing passwords!";
    return bless { passwords => {} }, $class;
  }

  my %peers = map { _resolve_host($_) => $_ } split( /,/, $peerlist );

  # seppuku
  delete $peers{ _resolve_host( Sys::Hostname::hostname() ) };

  my $self = {
    peers     => \%peers,
    passwords => {},
    authstore_port => $conf->{authstore_port},
  };

  return bless $self, $class;
}

sub store
{
  my ( $self, $job, $pw, $passphrase, $expire ) = @_;

  # stash locally
  $self->_store_local( $job, $pw, $passphrase, $expire );

  # store on hosts in the peerlist
  $_->push_write( json => [ 'store', $job, $pw, $passphrase, $expire ] )
    for values %{ $self->{clients} };
}

sub _store_local
{
  my ( $self, $job, $pw, $passphrase, $expire ) = @_;

  $self->{passwords}->{$job} = [ $pw, $passphrase, $expire ];

  # start expiration timer
  my $timer;
  $timer = AnyEvent->timer(
    after => $expire - time(),
    cb    => sub {
      delete $self->{passwords}->{$job};
      undef $timer;
    },
  );
}

sub get
{
  my ( $self, $job ) = @_;
  return $self->{passwords}->{$job};
}

sub start
{
  my $self = shift;
  $self->start_server;
  $self->start_client( rand(5), $_ ) for values %{ $self->{peers} };
}

sub start_server
{
  my $self = shift;
  tcp_server(
    $self->{bind_address},
    $self->{authstore_port},
    sub {
      my ( $fh, $remote_ip, $remote_port ) = @_;

      INFO "authstore connection received at $remote_ip:$remote_port";

      if ( !exists $self->{peers}->{$remote_ip} )
      {
        WARN "peer connection from $remote_ip not in whitelist, dropping";
        close $fh;
        return;
      }

      my $on_json;
      $on_json = sub {
        my ( $h,   $req )  = @_;
        my ( $cmd, @args ) = @$req;

        if ( $cmd eq 'store' )
        {
          my ( $jobid, $pw, $passphrase, $expire ) = @args;
          DEBUG "got passwords for job $jobid from $remote_ip:$remote_port";
          $self->_store_local( $jobid, $pw, $passphrase, $expire );
        }
        elsif ( $cmd eq 'expire' )
        {
          my ($job) = @args;
          delete $self->{passwords}->{$job};
        }
        elsif ( $cmd eq 'ping' )
        {
          $h->push_write( json => ['pong'] );
        }
        $h->push_read( json => $on_json );
      };

      my $handle;
      $handle = AnyEvent::Handle->new(
        fh      => $fh,
        tls     => 'accept',
        tls_ctx => Pogo::Dispatcher->ssl_ctx,
        on_error => sub {
          my $fatal = $_[1];
          ERROR sprintf( "%s error reported while talking to authstore at %s:%s: $!",
          $fatal ? 'fatal' : 'non-fatal', $remote_ip, $remote_port );
          undef $self->{handle};
        },

        on_eof  => sub {
          INFO "peer connection closed from $remote_ip:$remote_port";
          undef $handle;
        },
      );
      $handle->push_read( json => $on_json );
    },
    sub {
      INFO "listening for authstore connections on " . $_[1] . ':' . $_[2];
      return 0;
    },
  );
}

# called for each peer
sub start_client
{
  my ( $self, $interval, $server ) = @_;
  INFO sprintf( "initiating connection to %s in %0.2f secs", $server, $interval );
  my $port = $self->{authstore_port};

  my $connect_handler = sub {
    my $fh = shift;
    if ( !$fh )
    {
      ERROR "peer connection to $server failed: $!";
      $self->start_client( rand(30), $server );
      return;
    }
    DEBUG "connection to $server successful";

    my $handle;
    $handle = AnyEvent::Handle->new(
      fh       => $fh,
      tls      => 'connect',
      tls_ctx  => Pogo::Dispatcher->ssl_ctx,
      no_delay => 1,
      on_eof   => sub {
        delete $self->{clients}->{$server};
        ERROR "peer connection to $server closed (EOF)";
        undef $handle;
        $self->start_client( rand(30), $server );
      },
      on_error => sub {
        my $fatal = $_[1];
        undef $handle;
        delete $self->{clients}->{$server};
        ERROR sprintf( "%s connection error reported: %s", $fatal ? 'fatal' : 'non-fatal', $! );
        $self->start_client( rand(30), $server );
      },
      on_starttls => sub {
        my ( $handle, $success, $errmsg ) = @_;
        if ( !$success )
        {
          ERROR "tls handshake to $server failed: $errmsg";
          return;
        }
        DEBUG "tls handshake successful, exchanging passwords";
        $self->{clients}->{$server} = $handle;

        # send over all the goods
        while ( my ( $job, $pwent ) = each %{ $self->{passwords} } )
        {
          $handle->push_write( json => [ 'store', $job, @$pwent ] );
        }
      },
    );
  };

  my $timer;
  $timer = AnyEvent->timer(
    after => $interval,
    cb    => sub {
      undef $timer;
      INFO sprintf( "initializing connection to %s:%s", $server, $port );
      tcp_connect( $server, $port, $connect_handler );
    },
  );
}

sub _resolve_host
{
  return inet_ntoa( ( gethostbyname( $_[0] ) )[4] );
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
