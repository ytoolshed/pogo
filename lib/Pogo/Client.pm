package Pogo::Client;

use common::sense;

use JSON qw(encode_json);
use LWP::UserAgent;
use HTTP::Request::Common qw(GET POST);
use Log::Log4perl qw(:easy);
use Pogo::Job;

our $VERSION = '0.0.1';

sub new {
    my ( $class, $url ) = @_;

    LOGDIE 'no API URL specified'
        unless defined $url;

    my $self = {
        api => $url,
        ua  => LWP::UserAgent->new(
            timeout => 65,
            agent   => "Pogo/$VERSION",
            )

    };

    DEBUG "api = $url";
    bless $self, $class;
    return $self;
}

sub ping {
    my ( $self ) = @_;

    # GET /v1/ping
    my $uri = $self->{ api } . '/v1/ping';
    return $self->{ ua }->request( GET $uri );
}

sub listjobs {
    my ( $self, $args ) = @_;

    # TODO: validate arguments

    my $uri = URI->new();
    $uri->query_form( $args );

    # GET /v1/jobs
    my $uri = $self->{ api } . '/v1/jobs' . ( defined $uri->query() ? "?".$uri->query() : ''  );
    return $self->{ ua }->request( GET $uri );
}

sub get_job {
    my ( $self, $jobid ) = @_;

    LOGDIE 'no jobid specified'
        unless $jobid;

    # GET /v1/jobs/:jobid
    my $uri = $self->{ api } . "/v1/jobs/$jobid";
    return $self->{ ua }->request( GET $uri );
}

sub submit_job {
    my ( $self, $args ) = @_;

    # TODO validate arguments


    # POST /v1/jobs
    my $uri = $self->{ api } . '/v1/jobs';
    return $self->{ ua }->request( POST $uri, $args );
}

sub check_arguments {
    my ( $args, $checks ) = @_;

    foreach my $arg ( keys %$args ) {
        LOGDIE "invalid argument '$arg'"
            unless $checks->{ $arg };

        LOGDIE "bad value '$args->{ $arg }' for argument '$arg'"
            unless $checks->{ $arg }->( $args->{ $arg } );
    }
}

1;

=pod

=head1 NAME

Pogo::Client - Module for interacting with Pogo.

=head1 SYNOPSIS

    my $uri = 'http://pogoapi.example.com:4080';
    my $client = Pogo::Client->new( $uri );

    $client->ping()
        or die "couldn't ping pogo service at $uri";

=head1 DESCRIPTION

Long description...

=head1 METHODS

B<new>

=over 2

Create a new Pogo client. Accepts a single argument, the URL of the Pogo API.

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
