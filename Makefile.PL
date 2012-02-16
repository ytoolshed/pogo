#!/usr/bin/env perl -w

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

use common::sense;
use inc::Module::Install;

name 'pogo';
all_from 'lib/Pogo.pm';
perl_version '5.008';

requires 'AnyEvent';
requires 'AnyEvent::HTTPD' => 0.90;
requires 'Authen::PAM';
requires 'Carp';
requires 'Crypt::OpenSSL::RSA';
requires 'Crypt::OpenSSL::X509' => 1.6;
requires 'Data::Dumper';
requires 'Digest::MD5';
requires 'Fcntl';
requires 'File::Slurp';
requires 'File::Temp';
requires 'Getopt::Long';
requires 'GnuPG';
requires 'HTML::Entities';
requires 'HTTP::Request';
requires 'IO::File';
requires 'IO::Handle';
requires 'IPC::Open3';
requires 'JSON';
requires 'JSON::XS';
requires 'LWP::UserAgent';
requires 'List::Util';
requires 'Log::Log4perl';
requires 'MIME::Base64';
requires 'MIME::Types';
requires 'Module::Pluggable';
requires 'Net::SSLeay';
requires 'Net::ZooKeeper';
requires 'PasswordMonkey';
requires 'POSIX';
requires 'Pod::Find';
requires 'Pod::Usage';
requires 'Scalar::Util';
requires 'Set::Scalar';
requires 'Socket';
requires 'Storable';
requires 'String::Glob::Permute';
requires 'Sys::Hostname';
requires 'Template';
requires 'Term::ReadKey';
requires 'Time::HiRes';
requires 'URI';
requires 'YAML::XS';
requires 'common::sense';
requires 'constant';
requires 'Plack';
requires 'Plack::Handler::AnyEvent::HTTPD';

test_requires 'FindBin';
test_requires 'Net::SSLeay';
test_requires 'Proc::Simple';
test_requires 'Test::Exception';
test_requires 'Test::More';
test_requires 'Test::MockObject';
test_requires 'Test::Deep';
# test_requires 'TAP::Formatter::JUnit';

# requires_external_bin 'java';

postamble <<'HUDSONSTUFF';

# hudson targets
TESTRESULTDIR := ./test-results
TESTDIR := ./t
TESTS := $(wildcard $(TESTDIR)/*.t)
TESTRESULTS := $(patsubst $(TESTDIR)/%.t,$(TESTRESULTDIR)/%.xml,$(TESTS))

hudson : $(TESTS) $(TESTRESULTS)
  FORMATTER := --formatter TAP::Formatter::JUnit

hudson-clean :
	rm -f $(TESTRESULTS)
	rm -rf $(TESTRESULTDIR)

$(TESTS) : | $(TESTRESULTDIR)

$(TESTRESULTDIR) :
	mkdir $(TESTRESULTDIR)

$(TESTRESULTDIR)/%.xml : $(TESTDIR)/%.t
	prove -Ilib -I$(TESTDIR)/lib --timer $(FORMATTER) $< > $@ || exit 0

HUDSONSTUFF

WriteAll;

1;

# vim:syn=perl:sw=2:ts=2:sts=2:et:fdm=marker
