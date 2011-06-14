package Pogo::Plugin::HTMLEncode::Example;

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
use warnings;
use strict;


# constructor has to be named new()
sub new { return bless( {}, $_[0] ); }

# mandatory method html_encode has to handle data structures recursively
sub html_encode {
    my $self = shift;
    my $value = shift;

    if ( ref $value eq 'HASH' ) {
        foreach my $key ( keys %{ $value } ) {
            $value->{ $key } = $self->html_encode( $value->{ $key } );
        }
        return $value;

    } elsif ( ref $value eq 'ARRAY' ) {
        return [ map { $self->html_encode( $_ ) } @$value ];
    }

    $value =~ s/&/ENCODED THIS [ &amp; ]/g;
    $value =~ s/</ENCODED THIS [ &lt; ]/g;
    $value =~ s/>/ENCODED THIS [ &gt; ]/g;
    $value =~ s/"/ENCODED THIS [ &quot; ]/g;
    $value =~ s/'/ENCODED THIS [ &#39; ]/g;

    return $value;
}

# indicates the priority for this plugin, versus other possible
# HTML-encoding plugins
sub priority { return -1; }

1;

=pod

=head1 NAME

Pogo::Plugin::HTMLEncode::Example

=head1 SYNOPSIS

    package Pogo::Plugin::HTMLEncode::MyPlugin;

    sub new { return bless( {}, $_[0] ); }

    sub html_encode {
        my ($self,$data) = @_;

        # manipulate $data recursively...
        ...

        return $data
    }

    sub priority { return 5; }

    1;

=head1 DESCRIPTION

Pogo comes installed with a default scheme (Pogo::Plugin::HTMLEncode::Default)
for encoding user-provided data so that it can safely be displayed in an 
HTML/Javascript context, using HTML::Entities::encode_entities(). For the 
vast majority of users that will work just fine, but some installations 
may require a custom filter to be applied. The plugin architecture allows 
for an easy way to do this.

Essentially you'll provide a set of three required methods in your plugin
module, and then install it in the same directory as this module. As long
as it returns the highest priority of any module in the directory, it will
be loaded and used.


=head1 REQUIRED METHODS

=over 4

=item new():

The constructor for the class has to be named new(). It won't be able
to take any parameters.


=item html_encode():

Must deal with recursive data structures


=item priority():

Should just return the priority so that Pogo::HTTP::Server can choose
 a plugin, like:

    sub priority { return 10; }

=back

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
