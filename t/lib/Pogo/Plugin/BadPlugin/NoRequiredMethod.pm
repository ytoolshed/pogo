package Pogo::Plugin::BadPlugin::NoRequiredMethod;

# only new() and priority

sub new { return bless( {}, $_[0] ); }

sub priority { return 2; }

1;
