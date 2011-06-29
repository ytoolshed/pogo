package PogoTester;

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

use Time::HiRes qw(sleep);
use Log::Log4perl qw(:easy);

use AnyEvent::Handle;
use AnyEvent::Socket qw(tcp_connect);
use AnyEvent::TLS;
use AnyEvent;
use Carp qw(croak confess);
use Crypt::OpenSSL::RSA;
use Crypt::OpenSSL::X509;
use Data::Dumper;
use MIME::Base64 qw(encode_base64);
use Exporter 'import';
use FindBin qw($Bin);
use JSON::XS ();
use LWP;
use Net::SSLeay;
use Template;
use YAML::XS qw(LoadFile);
use File::Copy;
use File::Path;

use lib "$Bin/../lib";
use lib "$Bin/../../lib";

use Pogo::Engine;
use Pogo::Engine::Store qw(store);
use Pogo::Dispatcher::AuthStore;
use Pogo::Client;
use PogoTesterProc;
use IO::Socket;

our @EXPORT =
  qw(test_pogo derp dispatcher_rpc worker_rpc authstore_rpc encrypt_secret decrypt_secret client);

Log::Log4perl::init("$Bin/conf/log4perl.conf");

my $bind_address = '127.0.0.1';
my $dispatcher_conf;
my $worker_conf;
my $client_conf;

my $zookeeper_proc;
my $dispatcher_proc;
my $worker_proc;

my $pogo_client;

sub test_pogo(&)
{
  my $cb = shift;

  chdir($Bin);
  $dispatcher_conf = LoadFile("$Bin/conf/dispatcher.conf");
  $worker_conf     = LoadFile("$Bin/conf/worker.conf");
  $client_conf     = LoadFile("$Bin/conf/client.conf");

  if ( !defined $ENV{POGO_PERSIST} )
  {
    system("rm -rf $Bin/.tmp");
    mkdir "$Bin/.tmp"
      unless -d "$Bin/.tmp";
    start_zookeeper();
    start_dispatcher();
    sleep 2;
    start_worker();
  }
  init_store();
  $cb->();
}

sub start_dispatcher
{
  if ( defined $dispatcher_proc
    and $dispatcher_proc->poll() )
  {
    return 0;
  }

  my @args = (
    '/usr/bin/env',                'perl', "-I$Bin/../lib", "-I$Bin/lib",
    "$Bin/../bin/pogo-dispatcher", "-f",   "$Bin/conf/dispatcher.conf"
  );

  my $starter = PogoTesterProc->new( "dispatcher", @args );

  $dispatcher_proc = $starter->start();

  sleep 5;

  LOGDIE sprintf( "Couldn't start dispatcher!  Check %s and %s",
    $starter->stderr_log_path, $starter->stdout_log_path )
    unless $dispatcher_proc->poll();

  DEBUG "dispatcher pid=", $dispatcher_proc->pid();
  return $dispatcher_proc->pid();
}

sub stop_dispatcher
{
  return if !$dispatcher_proc or !$dispatcher_proc->poll();

  $dispatcher_proc->kill();
  undef $dispatcher_proc;
}

sub start_zookeeper
{
  if ( defined $zookeeper_proc
    and $zookeeper_proc->poll() )
  {
    return 0;
  }

  my $cmdcmd =
    "$Bin/../build/zookeeper/bin/zkServer.sh print-cmd " . "$Bin/conf/zookeeper.conf 2>/dev/null";
  my $cmd = `$cmdcmd`;

  my $starter = PogoTesterProc->new( 'zookeeper', $cmd );

  $zookeeper_proc = $starter->start();
  DEBUG "zookeeper pid=", $zookeeper_proc->pid();

  for ( 1 .. 10 )
  {
    if ( test_zookeeper() )
    {
      DEBUG "Zookeeper is ok.";
      return $zookeeper_proc->pid();
    }
    sleep 1;
    DEBUG "Zookeeper not up yet.";
  }

  LOGDIE "Couldn't start zookeeper";
  return;
}

sub stop_zookeeper
{
  return if !defined $zookeeper_proc or !$zookeeper_proc->poll();

  $zookeeper_proc->kill();
  undef $zookeeper_proc;
}

sub test_zookeeper
{
  my $port;
  my $conf = "$Bin/conf/zookeeper.conf";

  open F, "<$conf" or die "$conf: $!";
  while (<F>)
  {
    if (/clientPort\s*=\s*(\d+)/)
    {
      $port = $1;
      last;
    }
  }
  close(F);

  if ( !defined $port )
  {
    LOGDIE "Can't find zk port in $conf";
  }

  DEBUG "Contacting zookeeper on port $port";

  my $s = IO::Socket::INET->new(
    PeerHost => 'localhost',
    PeerPort => $port,
  ) or return 0;

  $s->write("ruok\n");
  $s->read( my $buf, 1024 );

  DEBUG "Zookeeper said: $buf";

  if ( $buf eq "imok" )
  {
    return 1;
  }

  return 0;
}

sub start_worker
{
  if ( defined $worker_proc
    and $worker_proc->poll() )
  {
    return 0;
  }

  my @args = (
    '/usr/bin/env',            'perl', "-I$Bin/../lib", "-I$Bin/lib",
    "$Bin/../bin/pogo-worker", '-f',   "$Bin/conf/worker.conf"
  );

  my $starter = PogoTesterProc->new( 'worker', @args );

  $worker_proc = $starter->start();

  sleep 1;    #TODO FIX

  LOGDIE sprintf( "Couldn't start worker!  Check %s and %s",
    $starter->stderr_log_path, $starter->stdout_log_path )
    unless $worker_proc->poll();

  DEBUG "worker pid=", $worker_proc->pid();
  return $worker_proc->pid();
}

sub stop_worker
{
  return if !defined $worker_proc or !$worker_proc->poll();

  $worker_proc->kill();
  undef $worker_proc;
}

sub init_store
{
  Pogo::Engine::Store->init($dispatcher_conf);
  Pogo::Dispatcher::AuthStore->init( { peers => ['localhost'] } );
}

# send raw json-rpc back and forth to our authstore port
sub authstore_rpc
{
  my ( $self, $rpc ) = @_;
  my $cv = AnyEvent->condvar;
  if ( !defined $self->{authstore_handle} )
  {
    DEBUG "creating new authstore handle";
    tcp_connect(
      $self->{bind_address},
      $self->{authstore_port},
      sub {
        my ( $fh, $host, $port ) = @_;
        if ( !$host && !$port )
        {
          ERROR "connection failed: $!";
          return;
        }
        DEBUG "connection successful, starting SSL negotiation";
        $self->{authstore_handle} = AnyEvent::Handle->new(
          fh       => $fh,
          tls      => 'connect',
          tls_ctx  => $self->{authstore_ctx},
          no_delay => 1,
          on_eof   => sub {
            delete $self->{authstore_handle};
            INFO "connection closed to $host:$port";
          },
          on_error => sub {
            delete $self->{authstore_handle};
            my $fatal = $_[1];
            LOGDIE
              sprintf( "$host:$port reported %s error: %s", $fatal ? 'fatal' : 'non-fatal', $! );
          },
        ) || LOGDIE "couldn't create handle: $!";
        $self->{authstore_handle}->push_write( json => $rpc );
        $self->{authstore_handle}->push_read( json => sub { $cv->send( $_[1] ); }, );
      },
    );
  }
  else
  {
    $self->{authstore_handle}->push_write( json => $rpc );
    $self->{authstore_handle}->push_read( json => sub { $cv->send( $_[1] ); }, );
  }

  return $cv->recv;
}

# currently unused, we use the client instead
sub dispatcher_rpc
{
  my $rpc = shift;
  my $url = sprintf( 'http://%s:%d/api/v3', $bind_address, $dispatcher_conf->{http_port} );
  my $res = LWP::UserAgent->new->post( $url, { 'r' => JSON::XS::encode_json($rpc) } );
  LOGDIE "request failed: " . $res->status_line
    unless $res->is_success;
  return JSON::XS::decode_json( $res->decoded_content );
}

sub worker_rpc
{
  my $rpc = shift;
  my $cv  = AnyEvent->condvar;
  my $handle;
  $handle = AnyEvent::Handle->new(
    connect => [ $bind_address, $dispatcher_conf->{worker_port} ],
    tls     => 'connect',
    tls_ctx => {
      key_file  => "$Bin/conf/worker.key",
      cert_file => "$Bin/conf/worker.cert",
      ca_file   => "$Bin/conf/dispatcher.cert",
      verify    => 1,
      verify_cb => sub {
        my $preverify_ok = $_[4];
        my $cert         = $_[6];
        DEBUG sprintf( "certificate: %s", AnyEvent::TLS::certname($cert) );
        return $preverify_ok;
      },
    },
    no_delay => 1,
    on_error => sub {
      $handle->destroy;
      my $fatal = $_[1];
      LOGDIE sprintf(
        "%s:%d reported %s error: %s",
        $bind_address,
        $dispatcher_conf->{worker_port},
        $fatal ? 'fatal' : 'non-fatal', $!
      );
    },
  );
  $handle->push_write( json => $rpc );
  $handle->push_read( json => sub { $cv->send( $_[1] ); } );

  return $cv->recv;
}

sub encrypt_secret
{
  my $secret = shift;
  Crypt::OpenSSL::RSA->import_random_seed();
  my $x509    = Crypt::OpenSSL::X509->new_from_file( $client_conf->{worker_cert} );
  my $rsa_pub = Crypt::OpenSSL::RSA->new_public_key( $x509->pubkey() );
  return encode_base64( $rsa_pub->encrypt($secret) );
}

sub decrypt_secret
{
  my $secret = shift;
  my $private_key =
    Crypt::OpenSSL::RSA->new_private_key( scalar read_file $worker_conf->{worker_key} );
  return $private_key->decrypt( decode_base64($secret) );
}

sub client
{
  if ( !defined $pogo_client )
  {
    $pogo_client = Pogo::Client->new( $client_conf->{api} );
  }
  return $pogo_client;
}

END
{
  if ( defined $ENV{POGO_PERSIST} )
  {
    INFO "persisting started services";
    return;
  }
  stop_worker();
  stop_dispatcher();
  stop_zookeeper();
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

__END__

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
