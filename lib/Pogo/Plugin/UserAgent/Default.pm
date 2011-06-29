package Pogo::Plugin::UserAgent::Default;

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

use LWP::UserAgent qw();
use base 'LWP::UserAgent';

our $VERSION = '4.0'; # XXX: double check if there's a better way to set this...

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new( timeout => 65,
                                   agent   => "Pogo/LWP::UserAgent/$VERSION", );
    return bless( $self, $class );
}

# indicates the priority for this plugin, versus other possible HTML-encoding plugins
sub priority { return 1; }

1;
