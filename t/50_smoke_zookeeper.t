#!/usr/bin/env perl -w

# Copyright (c) 2010, Yahoo! Inc. All rights reserved.
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

use Test::Exception;
use Test::More tests => 6;

use Data::Dumper;
use AnyEvent;
use AnyEvent::Socket qw(tcp_connect);
use AnyEvent::Handle;
use Carp qw(confess);
use FindBin qw($Bin);
use Log::Log4perl qw(:easy);

use lib "$Bin/../lib";
use lib "$Bin/lib";

use PogoTester;

$SIG{ALRM} = sub { confess; };
alarm(60);

test_pogo
{
  my $cv;
  $cv = AnyEvent->condvar;
  tcp_connect 'localhost', '18121', sub {
    my ($fh) = @_;
    ok( defined $fh, "connect" );
    my $h;
    $h = AnyEvent::Handle->new(
      fh       => $fh,
      on_error => sub {
        warn "error $_[2]\n";
        $_[0]->destroy;
      },
      on_eof => sub {
        $h->destroy;    # destroy handle
        warn "done.\n";
      }
    );

    $h->push_read(
      chunk => 4,
      sub {
        my ( $handle, $data ) = @_;
        ok( $data eq 'imok', "imok" );
        $cv->send(1);
      }
    );

    $h->push_write("ruok\n");
  };

  ok( $cv->recv(), "cv recv" );

  $cv = AnyEvent->condvar;
  tcp_connect 'localhost', '18121', sub {
    my ($fh) = @_;
    ok( defined $fh, "connect" );
    my $h;
    $h = AnyEvent::Handle->new(
      fh       => $fh,
      on_error => sub {
        warn "error $_[2]\n";
        $_[0]->destroy;
      },
      on_eof => sub {
        $h->destroy;    # destroy handle
        warn "done.\n";
      }
    );

    $h->push_read(
      regex => qr/Node count: \d+/,
      sub {
        my ( $handle, $data ) = @_;
        $data =~ m/Node count: (\d+)/;
        my $nodes = $1;
        ok( $nodes == 13, "node count $nodes" );
        $cv->send(1);
      }
    );

    $h->push_write("stat\n");

  };

  ok( $cv->recv(), "cv recv" );

};

done_testing;

1;
