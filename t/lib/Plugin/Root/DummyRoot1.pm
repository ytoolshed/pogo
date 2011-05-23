use 5.008;

sub root_type() { return "dummyroot1"; }
sub transform() { return "dummyroot1 \${rootname} --cmd \${command}"; }
sub priority() { return 1; }

