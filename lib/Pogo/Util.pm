###########################################
package Pogo::Util;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use JSON qw( to_json from_json );

require Exporter;
our @EXPORT_OK = qw( http_response_json make_accessor struct_traverse
    array_intersection id_gen struct_locate required_params_check 
    json_decode http_response_json_ok http_response_json_nok
    jobid_valid
);
our @ISA = qw( Exporter );

###########################################
sub http_response_json {
###########################################
    my ( $data, $code ) = @_;

    $code = 200 if !defined $code;

    return [
        $code,
        [ 'Content-Type' => 'application/json' ],
        [ to_json( $data ) ],
    ];
}

###########################################
sub http_response_json_nok {
###########################################
    my ( $message ) = @_;

    return http_response_json(
        {   rc      => "nok",
            message => $message,
        }
    );
}

###########################################
sub http_response_json_ok {
###########################################
    my ( $message ) = @_;

    return http_response_json(
        {   rc      => "ok",
            message => $message,
        }
    );
}

##################################################
sub required_params_check {
##################################################
    my ( $hash, $params, $continue ) = @_;

    if( !defined $params and $continue ) {
        return 0;
    }

    for my $param ( @$params ) {
        if( !exists $hash->{ $param } or
            !defined $hash->{ $param } ) {

            my $msg = "Mandatory parameter $param missing";

            if( $continue ) {
                LOGCARP $msg;
            } else {
                ERROR $msg;
                return 0;
            }
        }
    }

      # can be used to initialize the $self hash
    return map { $_ => undef } @$params;
}

##################################################
sub make_accessor {
##################################################
    my ( $package, $name ) = @_;

    # Lifted from Net::Amazon
    no strict qw(refs);

    my $code = <<EOT;
        *{"$package\\::$name"} = sub {
            my(\$self, \$value) = \@_;

            if(defined \$value) {
                \$self->{$name} = \$value;
            }
            if(exists \$self->{$name}) {
                return (\$self->{$name});
            } else {
                return "";
            }
        }
EOT
    if ( !defined *{ "$package\::$name" } ) {
        eval $code or die "$@";
    }
}

############################################################
sub struct_locate {
############################################################
    my ( $root, $path ) = @_;

    my $ref = $root;

    for my $part ( @$path ) {
        $ref = $ref->{ $part };
    }

    return $ref;
}

############################################################
sub struct_traverse {
############################################################
    my ( $root, $callbacks ) = @_;

    # use Data::Dumper;
    # DEBUG "struct_traverse: ", Dumper( \@_ );

    # Transforms a nested hash/array data structure depth-first and
    # executes defined callbacks.

    # array => sub { # on every array }
    #     { a => { b => [ c, d ] } }
    #     calls: c, [a, b],
    #            d, [a, b]
    #
    # leaf  => sub { # every leaf node calls with this path components }
    #     { a => { b => [ c,d ] } } =>
    #     calls: c, [a, b],
    #            d, [a, b]

    my @stack = ();
    $callbacks = {} if !defined $callbacks;

    push @stack, [ $root, [] ];

    while ( @stack ) {
        # DEBUG "stack is [", Dumper( \@stack ), "]";

        my $item = pop @stack;

        my ( $node, $path, $opts ) = @$item;
        $opts = {} if !defined $opts;

        last if !defined $node;

        if ( ref( $node ) eq "HASH" ) {
            for my $part ( keys %$node ) {
                my $path = [ @$path, $part ];
                push @$path, $node->{ $part } if !ref( $node->{ $part } );
                push @stack, [ $node->{ $part }, $path ];
            }
        } elsif ( ref( $node ) eq "ARRAY" ) {
            if ( exists $callbacks->{ array } ) {
                $callbacks->{ array }->( $node, $path, $opts );
            }
            my $idx = 0;
            for my $part ( @$node ) {
                push @stack,
                    [ $part, [ @$path, $part ], { array_idx => $idx } ];
                $idx++;
            }
        } else {
            if ( exists $callbacks->{ leaf } ) {
                # Remove one item from path
                my @dir_path = @$path;
                pop @dir_path;
                $callbacks->{ leaf }->( $node, \@dir_path, $opts );
            }
        }
    }

    return 1;
}

###########################################
sub array_intersection {
###########################################
    my ( $arr1, $arr2 ) = @_;

    my @intersection = ();

    my %count1 = ();
    my %count2 = ();

    foreach my $element ( @$arr1 ) {
        $count1{ $element } = 1;
    }

    foreach my $element ( @$arr2 ) {
        if ( $count2{ $element }++ ) {
            next;    # skip inner-2-dupes
        }
        if ( $count1{ $element } ) {
            push @intersection, $element;
        }
    }

    return @intersection;
}

my %LAST_ID = ();

##################################################
sub id_gen {
##################################################
    my ( $prefix ) = @_;

    $prefix = "id" if !defined $prefix;

    $LAST_ID{ $prefix } = 0 if !exists $LAST_ID{ $prefix };

    return sprintf "$prefix-%09d", $LAST_ID{ $prefix }++;
}

###########################################
sub json_decode {
###########################################
    my( $json ) = @_;

    my $data = undef;

    eval {
        $data = from_json( $json );
    };

    if( $@ ) {
        ERROR "Received invalid JSON";
        return $data;
    }

    return $data;
}

###########################################
sub jobid_valid {
###########################################
    my ( $jobid ) = @_;

    if( length( $jobid ) > 5 ) {
        return 1;
    }

    return 0;
}

1;

__END__

=head1 NAME

Pogo::Util - Pogo Utilities

=head1 SYNOPSIS

    use Pogo::Util qw( some_util_function );
    some_util_function();

=head1 DESCRIPTION

Some useful utilities, used throughout Pogo.

=head1 FUNCTIONS

=over 4

=item C<http_response_json( $data, [$code] )> 

Take a data structure and turn it into JSON, take an optional HTTP response 
code (defaults to OK 200) and return a PSGI-compatible structure for apps:

    use Pogo::Util qw( http_response_json );

    my $callback = sub {
       # ... 
       return http_response_json( { message => "yay!" } );
    }

=item C<__PACKAGE__-E<gt>make_accessor( $name )> 

Poor man's Class::Struct. For example, to add an accessor for an instance 
variable C<color> to your class, use

    package Foobar;
    use Pogo::Util qw( make_accessor );
    __PACKAGE__->make_accessor( "color" );

    sub new { bless {}, shift; }

    package main;

    my $foobar = Foobar->new();
    $foobar->color( "orange" );
    print "Foobar's color is ", $foobar->color(), "\n";

=back

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

