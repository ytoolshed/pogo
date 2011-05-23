use 5.008;

sub root_type() { return "dummyroot3"; }
sub transform() { return "dummyroot3 \${rootname} --cmd \${command}"; }
sub priority() { return 10; }

