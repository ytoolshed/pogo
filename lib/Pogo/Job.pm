###########################################
package Pogo::Job;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use AnyEvent;
use AnyEvent::Strict;
use Pogo::Util qw( make_accessor );
use URI;

my @FIELDS = qw(
range
namespace
command
user
password
client_private_key
pvt_key_passphrase
run_as
timeout
job_timeout
prehook
posthook
retry
requesthost
email
im_handle
message
invoked_as
client
);

for my $field ( @FIELDS ) {
    make_accessor __PACKAGE__, $field;
}

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = {
        map( { $_ => undef } @FIELDS ),
        %options,
    };

    bless $self, $class;
}

###########################################
sub from_query {
###########################################
    my( $class, $url_encoded ) = @_;

    my $uri = URI->new();
    $uri->query( $url_encoded );

    return $class->new( $uri->query_form() );
}

###########################################
sub urlencode {
###########################################
    my( $self ) = @_;

    my @keyvalues = ();

    for my $field ( @FIELDS ) {
        next if !defined $self->{ $field };
        push @keyvalues, $field, $self->{ $field };
    }

    my $uri = URI->new();
    $uri->query_form( @keyvalues );

    return $uri->query();
}

###########################################
sub as_hash {
###########################################
    my( $self ) = @_;

    my $hash = {};

    for my $field ( @FIELDS ) {
        next if !defined $self->{ $field };
        $hash->{ $field } = $self->{ $field };
    }

    return $hash;
}
    
###########################################
sub as_string {
###########################################
    my( $self ) = @_;
    
    my $string = "";

    for my $field ( @FIELDS ) {
        next if !defined $self->{ $field };
        $string .= ", " if length $string;
        $string .= "$field: $self->{ $field }";
    }

    return $string;
}

1;

__END__

=head1 NAME

Pogo::Job - Pogo Job

=head1 SYNOPSIS

    use Pogo::Job;

    my $job = Pogo::Job->new();

=head1 DESCRIPTION

Pogo::Job holds parameters for a job, including the target hosts, the
command, and the configuration. See C<Pogo::API::V1> for a description
of all parameters and their corresponding accessors (section C<POST /v1/jobs>).

=head1 LICENSE

Copyright (c) 2010-2012 Yahoo! Inc. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
imitations under the License.

=head1 AUTHORS

Mike Schilli <m@perlmeister.com>
Ian Bettinger <ibettinger@yahoo.com>

Many thanks to the following folks for implementing the
original version of Pogo: 

Andrew Sloane <andy@a1k0n.net>, 
Michael Fischer <michael+pogo@dynamine.net>,
Nicholas Harteau <nrh@hep.cat>,
Nick Purvis <nep@noisetu.be>,
Robert Phan <robert.phan@gmail.com>,
Srini Singanallur <ssingan@yahoo.com>,
Yogesh Natarajan <yogesh_ny@yahoo.co.in>

