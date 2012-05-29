# This is a patched-up version of Plack::Handler::AnyEvent::HTTPD until
#   https://github.com/miyagawa/Plack-Handler-AnyEvent-HTTPD/pull/1
# or
#   https://rt.cpan.org/Ticket/Display.html?id=76033
# get fixed.

package Plack::Handler::AnyEvent::HTTPD;

use strict;
use 5.008_001;
our $VERSION = '0.01';

use Plack::Util;
use HTTP::Status;
use URI::Escape;

sub new {
    my($class, %args) = @_;
    bless {%args}, $class;
}

sub register_service {
    my($self, $app) = @_;

    my $httpd = Plack::Handler::AnyEvent::HTTPD::Server->new(
        port => $self->{port} || 9000,
        host => $self->{host},
        request_timeout => $self->{request_timeout},
        app  => $app,
    );

    $self->{server_ready}->({
        port => $httpd->port,
        host => $httpd->host,
        server_software => 'AnyEvent::HTTPD',
    }) if $self->{server_ready};

    $self->{_httpd} = $httpd;
}

sub run {
    my $self = shift;
    $self->register_service(@_);

    $self->{_httpd}->run;
}

package Plack::Handler::AnyEvent::HTTPD::Server;
use parent qw(AnyEvent::HTTPD::HTTPServer);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(
        connection_class => 'Plack::Handler::AnyEvent::HTTPD::Connection',
        @_,
    );
    $self->reg_cb(
        connect => sub {
            my($self, $con) = @_;
            Scalar::Util::weaken($self);
            $self->{conns}->{$con} = $con->reg_cb(
                request => sub {
                    my($con, $meth, $url, $hdr, $cont) = @_;
                    $self->handle_psgi_request($con, $meth, $url, $hdr, $cont);
                },
            );
        },
        disconnect => sub {
            my($self, $con) = @_;
            $con->unreg_cb(delete $self->{conns}->{$con});
        },
    );

    $self->{state} ||= {};

    $self;
}

sub handle_psgi_request {
    my($self, $con, $meth, $url, $hdr, $cont) = @_;

    my($path_info, $query) = split /\?/, $url, 2;

    my $env = {
        REMOTE_ADDR         => $con->{host},
        SERVER_PORT         => $self->port,
        SERVER_NAME         => $self->host,
        SCRIPT_NAME         => '',
        REQUEST_METHOD      => $meth,
        PATH_INFO           => URI::Escape::uri_unescape($path_info),
        REQUEST_URI         => $url,
        QUERY_STRING        => $query,
        SERVER_PROTOCOL     => 'HTTP/1.0', # no way to get this from HTTPConnection
        'psgi.version'      => [ 1, 1 ],
        'psgi.errors'       => *STDERR,
        'psgi.url_scheme'   => 'http',
        'psgi.nonblocking'  => Plack::Util::TRUE,
        'psgi.streaming'    => Plack::Util::TRUE,
        'psgi.run_once'     => Plack::Util::FALSE,
        'psgi.multithread'  => Plack::Util::FALSE,
        'psgi.multiprocess' => Plack::Util::FALSE,
        'psgi.input'        => do {
            open my $input, "<", \(ref $cont ? '' : $cont);
            $input;
        },
        'psgix.io'          => $con->{fh},
    };

    $env->{CONTENT_TYPE}   = delete $hdr->{'content-type'};
    $env->{CONTENT_LENGTH} = delete $hdr->{'content-length'};

    while (my($key, $val) = each %$hdr) {
        $key =~ tr/-/_/;
        $env->{"HTTP_" . uc $key} = $val;
    }

    my $res = Plack::Util::run_app($self->{app}, $env);

    Scalar::Util::weaken($con);
    my $respond = sub {
        my $res = shift;

        my %headers;
        while ( my($key, $val) = splice @{$res->[1]}, 0, 2) {
            $headers{$key} = exists $headers{$key} ? "$headers{$key}, $val" : $val;
        }
        my @res = ($res->[0], HTTP::Status::status_message($res->[0]), \%headers);

        if (defined $res->[2]) {
            my $content;
            Plack::Util::foreach($res->[2], sub { $content .= $_[0] });

            # Work around AnyEvent::HTTPD bugs that it sets
            # Content-Length even when it's not necessary
            if (!$content && Plack::Util::status_with_no_entity_body($res->[0])) {
                $content = sub { $_[0]->(undef) if $_[0] };
            }

            $con->response(@res, $content) if $con;

            return;
        } else {
            # Probably unnecessary, but in case ->write is
            # called before the poll callback is execute.
            my @buf;
            my $data_cb = sub { push @buf, $_[0] };
            $con->response(@res, sub {
                # TODO $data_cb = undef -> Client Disconnect
                $data_cb = shift;
                if ($data_cb && @buf) {
                    $data_cb->($_) for @buf;
                    @buf = ()
                }
            }) if $con;

            return Plack::Util::inline_object
                write => sub { $data_cb->($_[0]) if $data_cb },
                close => sub { $data_cb->(undef) if $data_cb };
        }
    };

    ref $res eq 'CODE' ? $res->($respond) : $respond->($res);
}

sub run {
    my $self = shift;
    $self->{cv} = AE::cv;
    $self->{cv}->recv;
}

package Plack::Handler::AnyEvent::HTTPD::Connection;
use parent qw(AnyEvent::HTTPD::HTTPConnection);

# Don't parse content
sub handle_request {
    my($self, $method, $uri, $hdr, $cont) = @_;

    if( $hdr->{connection} ) {
        $self->{keep_alive} = ($hdr->{connection} =~ /keep-alive/io);
    }
    $self->event(request => $method, $uri, $hdr, $cont);
}

package Plack::Handler::AnyEvent::HTTPD;

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

Plack::Handler::AnyEvent::HTTPD - Plack handler to run PSGI apps on AnyEvent::HTTPD

=head1 SYNOPSIS

  plackup -s AnyEvent::HTTPD --port 9090

=head1 DESCRIPTION

Plack::Handler::AnyEvent::HTTPD is a Plack handler to run PSGI apps on AnyEvent::HTTPD module.

=head1 LIMITATIONS

=over 4

=item *

C<< $env->{SERVER_PROTOCOL} >> is always I<HTTP/1.0> regardless of the request version.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<AnyEvent::HTTPD>

=cut
