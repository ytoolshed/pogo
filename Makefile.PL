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

use inc::Module::Install;

name 'pogo';
all_from 'lib/Pogo.pm';
perl_version '5.008';

requires 'common::sense';
requires 'AnyEvent';
requires 'AnyEvent::HTTPD';
requires 'Authen::PAM';
requires 'constant';
requires 'Exporter';
requires 'Data::Dumper';
requires 'Text::Wrap';
requires 'Term::ReadKey';
requires 'Pod::Escapes';
requires 'version';
requires 'YAML';
requires 'ExtUtils::Install';
requires 'ExtUtils::CBuilder';
requires 'ExtUtils::Manifest';
requires 'ExtUtils::Command';
requires 'Log::Log4perl';
requires 'ExtUtils::ParseXS';
requires 'CPAN';
requires 'Pod::Simple';
requires 'Pod::Parser';
requires 'Sysadm::Install';
requires 'Pod::Usage';
requires 'Getopt::Long';
requires 'ExtUtils::MakeMaker';
requires 'Module::Build';
requires 'local::lib';
requires 'Crypt::OpenSSL::RSA';
requires 'Crypt::OpenSSL::Random';
requires 'Crypt::OpenSSL::X509';
requires 'JSON';
requires 'File::Slurp';
requires 'GnuPG';
requires 'Module::Pluggable';
requires 'Net::SSLeay';
#requires 'Net::ZooKeeper';
requires 'AnyEvent::HTTPD';
requires 'JSON::XS'; 
requires 'Net::ZooKeeper';
requires 'MIME::Types';
requires 'PasswordMonkey';
requires 'Plack';
requires 'Proc::Simple';
requires 'Set::Scalar';
requires 'String::Glob::Permute';
requires 'Template';
requires 'Plack::Handler::AnyEvent::HTTPD';
requires 'YAML::LibYAML';
requires 'AnyEvent::HTTP';

test_requires 'Test::Harness';
test_requires 'Test';
test_requires 'Test::Simple';
test_requires 'Test::Deep';
test_requires 'Test::Exception';
test_requires 'Test::MockObject';
test_requires 'Test::Requires';

test_requires 'FindBin';
test_requires 'Net::SSLeay';
test_requires 'Proc::Simple';
test_requires 'Test::More';

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
