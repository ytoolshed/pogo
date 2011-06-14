package Pogo::Plugin;

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

use Log::Log4perl qw(:easy);
use Module::Pluggable search_path => ['Pogo::Plugin'], instantiate => 'new' ;

my $instance;

sub load
{
  my ( $class, $type, $args ) = @_;

  $class->_init();

  LOGDIE "Missing argument, type, to $class\->load()"
      unless $type;

  return $instance->{$type}
     if defined $instance->{$type};

  $instance->search_path( new => "Pogo::Plugin::$type" );
  DEBUG "looking for '$type' plugin";

  my @required_methods;
  @required_methods = @{ $args->{required_methods} }
    if $args->{required_methods};

  # check each potential plugin
  PLUGIN: foreach my $plugin_obj ($instance->plugins)
  {
    DEBUG "evaluating '$type' plugin: " . ref($plugin_obj);

    # priority() method is always required
    next PLUGIN unless $plugin_obj->can('priority');

    # check that other specified methods are present
    foreach my $required_method ( @required_methods )
    {
      next PLUGIN unless $plugin_obj->can($required_method);
    }

    DEBUG "found valid '$type' plugin: " . ref($plugin_obj) . ', priority: ' . $plugin_obj->priority;

    # compare to other loaded plugins of this type
    if ( ! defined $instance->{$type} )
    {
      $instance->{$type} = $plugin_obj;
    }
    elsif ( $plugin_obj->priority > $instance->{$type}->priority )
    {
      $instance->{$type} = $plugin_obj;
    }
  }

  LOGDIE "No appropriate '$type' plugin found. "
       . "lib/Pogo/Plugin/$type/Default.pm should have been part of the original installation?"
    unless $instance->{$type};

  DEBUG 'using ' . ref( $instance->{$type} ) . " for '$type' plugin";

  return $instance->{$type};
}

sub add_search_path
{
    my ( $self, $path ) = @_;

    DEBUG "Adding plugin search path: '$path'";
    $self->search_path( add => $path );
}

sub _init
{
    my $class = shift;

    return $instance
        if defined $instance;

    $instance = {};
    return bless( $instance, $class );
}


=pod

=head1 NAME

Pogo::Plugin

=head1 SYNOPSIS

    use Pogo::Plugin;

    my $widget = Pogo::Plugin->load( 'Widget', { required_methods => [ 'do_stuff' ] } );

    $widget->do_stuff();

Then within a .pm file in the lib/Pogo/Plugin/Widget/ directory:

    package Pogo::Plugin::Widget::MySpecialWidget;

    sub new {
        my $class = shift;
        return bless({},$class);
    }

    sub do_stuff {
        my $self = shift;

        # this is where you'll do stuff
        stuff();
    }

    sub priority { return 10; }

    1;


=head1 DESCRIPTION

To allow 3rd parties to modify Pogo's behavior and extend its functionality,
Pogo uses a plugin-based approach. Typically, each type of plugin comes with
a default plugin providing default functionality. If you want something
else, simply add another plugin with a priority() method that returns a 
higher value than the other installed plugins of that type. Pogo will
automaticallly use your module, no configuration file editing necessary.

=head1 METHODS

From the calling code's point of view, just one to be concerned about:

=over 4

=item load()

    load( $type )
    load( $type, \%args )

=back

C<$type> is the kind of plugin C<Pogo::Plugin> should attempt to load. For
example if you specify 'Widget', C<Pogo::Plugin> will look under
C<lib/Pogo/Plugin/Widget/> for potential plugins.

Specifying C<required_methods> in C<\%args> will require that any loaded 
plugins has the methods specified.

=head1 WRITING PLUGINS

To be filled out more completely later, but for now, refer to the default
plugin for the type you wish to override, as well as
L<Pogo::Plugin::HTMLEncode::Example>.

=head1 SEE ALSO

L<Pogo::Plugin::HTMLEncode::Example>, which provides a reasonable
explanation of the required methods for HTMLEncode plugins and their
expected functionality.

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


1;
