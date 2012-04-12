###########################################
package Pogo::Util;
###########################################
use strict;
use warnings;
use Log::Log4perl qw(:easy);
use JSON qw( to_json );

require Exporter;
our @EXPORT_OK = qw( http_response_json make_accessor struct_traverse
                     array_intersection id_gen);
our @ISA       = qw( Exporter );

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
sub struct_traverse {
############################################################
    my ( $root, $callbacks ) = @_;

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

    my @stack  = ();
    $callbacks = {} if !defined $callbacks;

    push @stack, [ $root, [] ];

    while( @stack ) {
        my $item = pop @stack;

        my($node, $path) = @$item;

        if(ref($node) eq "HASH") {
            for my $part (keys %$node) {
                push @stack, [ $node->{$part}, [@$path, $part] ];
            }
        } elsif( ref($node) eq "ARRAY") {
            if( exists $callbacks->{ array } ) {
                $callbacks->{ array }->( $node, $path );
            }
            for my $part ( @$node ) {
                push @stack, [ $part, [@$path, $part]];
            }
        } else {
            if( exists $callbacks->{ leaf } ) {
                  # Remove one item from path
                my @dir_path = @$path;
                pop @dir_path;
                $callbacks->{ leaf }->( $node, \@dir_path );
            }
        }
    }

    return 1;
}

###########################################
sub array_intersection {
###########################################
    my( $arr1, $arr2 ) = @_;

    my @intersection = ();

    my %count1 = ();
    my %count2 = ();

    foreach my $element ( @$arr1 ) {
        $count1{ $element } = 1;
    }

    foreach my $element ( @$arr2 ) {
        if( $count2{ $element }++ ) {
            next; # skip inner-2-dupes
        }
        if( $count1{ $element } ) {
            push @intersection, $element;
        }
    }

    return @intersection;
}

my %LAST_ID = ();

##################################################
sub id_gen {
##################################################
    my( $prefix ) = @_;

    $prefix = "id" if !defined $prefix;

    $LAST_ID{ $prefix } = 0 if !exists $LAST_ID{ $prefix };

    return sprintf "$prefix-%09d", $LAST_ID{ $prefix }++;
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

