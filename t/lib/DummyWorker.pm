package PogoDummyWorker;

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

use Pogo::Worker;

our $opts    = {};
our $execute = undef;

sub instance()
{
  if ( defined $opts->{log4perl} && -r $opts->{log4perl} )
  {
    Log::Log4perl::init( $opts->{log4perl} );
  }
  if ( defined $opts->{loglevel} )
  {
    Log::Log4perl::get_logger()->level( $opts->{loglevel} );
  }

  {
    die "Please set PogoDummyWorker::execute to a coderef" unless ref $execute eq 'CODE';

    no strict 'refs';
    *{'Pogo::Worker::Connection::real_execute'} = \&Pogo::Worker::Connection::execute;
    *{'Pogo::Worker::Connection::execute'}      = $execute;
  }
  return Pogo::Worker->instance($opts);
}

"The proles don't matter.";

1;

=pod

=head1 NAME

  CLASSNAME - SHORT DESCRIPTION

=head1 SYNOPSIS

CODE GOES HERE

=head1 DESCRIPTION

LONG_DESCRIPTION

=head1 METHODS

B<methodexample>

=over 2

methoddescription

=back

=head1 SEE ALSO

L<Pogo::Dispatcher>

=head1 COPYRIGHT

Apache 2.0

=head1 AUTHORS

  Andrew Sloane <asloane@yahoo-inc.com>
  Michael Fischer <mfischer@yahoo-inc.com>
  Nicholas Harteau <nrh@yahoo-inc.com>
  Nick Purvis <nep@yahoo-inc.com>
  Robert Phan <rphan@yahoo-inc.com>

=cut

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
