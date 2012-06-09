###########################################
package Pogo::Dispatcher::ControlPort::PSGI;
###########################################
use strict;
use warnings;
use JSON qw(from_json to_json);
use Plack::App::URLMap;
use Log::Log4perl qw(:easy);

###########################################
sub app {
###########################################
    my ( $class, $dispatcher ) = @_;

    my $app = Plack::App::URLMap->new;

    # map URLs to modules, like /status => ControlPort/Status.pm etc.
    for my $api ( qw( status v1 ) ) {

        my $module = __PACKAGE__;
        $module =~ s/::[^:]*$//;
        $module .= "::" . ucfirst( $api );

        eval "require $module";
        if ( $@ ) {
            die "Failed to load module $module ($@)";
        }

        DEBUG "Mounting /$api to module $module";

        $app->mount( "/$api" => $module->app( $dispatcher ) );
    }

    return $app;
}

__END__

=head1 NAME

Pogo::Dispatcher::ControlPort::PSGI - Pogo Dispatcher Internal ControlPort PSGI interface

=head1 SYNOPSIS

    use Pogo::Dispatcher::ControlPort::PSGI;
    my $app = Pogo::Dispatcher::ControlPort::PSGI->app();

=head1 DESCRIPTION

App handler for the Pogo dispatcher's internal ControlPort.

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

