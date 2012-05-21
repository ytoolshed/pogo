###########################################
package Pogo::AnyEvent::HTTP;
###########################################
use strict;
use warnings;

use AnyEvent::HTTP ();
use Sysadm::Install qw( slurp );
use File::Basename;

###########################################
sub http_any {
###########################################
    my( $method, $url, @args ) = @_;

    my $cb = pop @args;

    if( my $data = file_url_read( $url ) ) {
        my $hdr = { Status => "200" };
        return $cb->( $data, $hdr );
    }

    AnyEvent::HTTP::http_$method( $url, @args );
}

###########################################
sub http_get {
###########################################
    my( @args ) = @_;

    return http_any( "get", @args );
}

###########################################
sub http_post {
###########################################
    my( @args ) = @_;

    return http_any( "post", @args );
}

###########################################
sub file_url {
###########################################
    my( $url ) = @_;

    if( $url =~ m#^file://(.*)# ) {
        return $1;
    }

    return undef;
}

###########################################
sub file_url_read {
###########################################
    my( $url ) = @_;

    my $file = file_url( $url );

    while( ! -f $file ) {
        $file = dirname $file;
    }

    if( -f $file ) {
        return slurp $file;
    }

    return undef;
}

1;

__END__

=head1 NAME

Pogo::AnyEvent::HTTP

=head1 SYNOPSIS

    use Pogo::AnyEvent::HTTP;

    Pogo::AnyEvent::http_get( $url, sub {
      my( $data, $hdr ) = @_;
    } );

=head1 DESCRIPTION

Pogo::AnyEvent::HTTP extends AnyEvent::HTTP to support file:// URLs for 
testing.

=head1 AUTHOR

2012, Mike Schilli <mschilli@yahoo-inc.com>
