package Pogo::Dispatcher::WorkerConnection;

use strict;
use warnings;

use AnyEvent::Handle;
use Log::Log4perl qw(:easy);
use Socket qw(AF_INET inet_aton);

sub accept_handler
{
  my $class = shift;
  return sub {
    my ( $fh, $remote_ip, $remote_port ) = @_;
    # This is the accept callback handler for the user interface to the
    # dispatcher

    # Here we act like a constructor.  (We have no choice but to place
    # that functionality here, as AnyEvent::Socket only lets us specify
    # a code ref as an accept handler, and not a module name.)
    my $self = {
      handle      => undef,
      remote_host => undef,
      remote_ip   => $remote_ip,
      remote_port => $remote_port,
    };

    bless( $self, $class );

    INFO "worker connection recieved at " . $self->id;

    $self->{handle} = AnyEvent::Handle->new(
      fh      => $fh,
      tls     => 'accept',
      tls_ctx => Pogo::Dispatcher->ssl_ctx,
      on_eof  => sub {
        INFO "worker connection closed from " . $self->id;
        Pogo::Dispatcher->retire_worker($self);
        undef $self->{handle};
      },
      on_error => sub {
        my $fatal = $_[1];
        ERROR sprintf( "%s error reported while talking to worker at %s: $!",
          $fatal ? 'fatal' : 'non-fatal', $self->id );
        Pogo::Dispatcher->retire_worker($self);
        undef $self->{handle};
      },

      # We'll replace this later - need it to catch connections closing
      # before we're actively conversing with a worker
      on_read => sub { },
    );

    Pogo::Dispatcher->idle_worker($self);

    my $on_json;

    $on_json = sub {
      my ( $h,   $req )  = @_;
      my ( $cmd, @args ) = @$req;

      if ( $cmd eq 'idle' )
      {
        Pogo::Dispatcher->idle_worker($self);
      }
      elsif ( $cmd eq 'start' )
      {
        my ( $jobid, $host, $outputurl ) = @args;
        my $job = Pogo::Engine->job($jobid);
        LOGDIE "nonexistant job $jobid sent from worker " . $self->id unless $job;
        $job->start_host( $host, $outputurl );
      }
      elsif ( $cmd eq 'finish' )
      {
        my ( $jobid, $host, $exitcode, $msg ) = @args;
        my $job = Pogo::Server->job($jobid);
        LOGDIE "nonexistant job $jobid sent from worker " . $self->id unless $job;
        $job->finish_host( $host, $exitcode, $msg );
      }
      $h->push_read( json => $on_json );
    };
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

