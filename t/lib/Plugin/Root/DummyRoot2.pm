use 5.008;

sub root_type() { return "dummyroot2"; }
sub transform() { return "dummyroot2 \${rootname} --cmd \${command}"; }
sub priority() { return 5; }

