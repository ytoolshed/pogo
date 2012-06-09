###########################################
package Pogo::PasswordMonkey;
###########################################
use strict;
use warnings;
use PasswordMonkey;
use PasswordMonkey::Bouncer::Wait;
use PasswordMonkey::Filler;
use Log::Log4perl qw(:easy);

my @PARAMS_MANDATORY = qw( password );
my %PARAMS_DEFAULTS = (
    timeout                          => 60,
    "passwordmonkey.waiter.interval" => 2,
);

###########################################
sub new {
###########################################
    my ( $class, %options ) = @_;

    my $self = {
        %options,
    };

    bless $self, $class;
}

###########################################
sub startup {
###########################################
    my( $self ) = @_;

    $self->keyval_pairs();
    $self->param_update();
}

###########################################
sub param_update {
###########################################
    my( $self ) = @_;

    for my $key ( keys %PARAMS_DEFAULTS ) {
        if( !exists $self->{ keyvals }->{ $key } ) {
            $self->{ keyvalues }->{ $key } = $PARAMS_DEFAULTS{ $key };
        }
    }
    
      # check mandatory parameters
    for my $param ( @PARAMS_MANDATORY ) {
        if( !exists $self->{ keyvals }->{ $param } ) {
            LOGDIE "Mandatory parameter $param missing";
        }
    }
}

###########################################
sub keyval_pairs {
###########################################
    my( $self, $preset ) = @_;

    if( $preset ) {
        $self->{ keyvals } = $preset;
        return $preset;
    }

    $self->{ keyvals } = {};

    while( my $line = <STDIN> ) {
        chomp $line;
        my( $key, $value ) = split /=/, $line, 2;
        DEBUG "Storing parameter $key=$value";
        $self->{ keyvals }->{ $key } = $value;
    }
}

###########################################
sub go {
###########################################
    my( $self ) = @_;

    my $monkey = PasswordMonkey->new(
        timeout => $self->{ keyvals }->{ timeout }
    );

    my $waiter = PasswordMonkey::Bouncer::Wait->new( seconds => 2 );

    for my $plugin ( $self->filler_plugins() ) {

        eval "require $plugin";

        my $filler = $plugin->new(
            password => $self->{ keyvals }->{ password }
        );

        $filler->bouncer_add( $waiter );
        $monkey->filler_add( $filler );
    }

    $monkey->spawn( @ARGV );
    $monkey->go();

    if( ! $monkey->is_success ) {
        if( $monkey->timed_out ) {
            ERROR "$0: Timed out";
            exit 254;
        } else {
            ERROR "$0: Error: ", $monkey->exit_status();
            my $exit_code = ($monkey->exit_status() >> 8);
            ERROR "$0: Exit code $exit_code";
            exit $exit_code;
        }
    }

    INFO "$0 done.";

}

###########################################
sub filler_plugins {
###########################################
    my( $self ) = @_;

    eval { 
        PasswordMonkey::Filler->plugins();
    };

    if( $@ ) {
        eval <<EOT
package PasswordMonkey::Filler;
use Module::Pluggable search_path => [ 'PasswordMonkey::Filler' ];
EOT
    }

    my $fillers = PasswordMonkey::Filler->new();
    my @plugins = $fillers->plugins();

    return @plugins;
}

1;

__END__

=head1 NAME

    Pogo::PasswordMonkey - Run a command and fill in password prompts

=head1 SYNOPSIS

    use Pogo::PasswordMonkey;

    my $monkey = Pogo::PasswordMonkey->new();
      # read parameters from STDIN
    $monkey->startup();
    $monkey->go( "sudo ls" );

=head1 DESCRIPTION

The meat behind pogo-pw.

=head1 AUTHOR

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

