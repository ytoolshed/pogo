package Pogo::Plugin::MultiPlugin::One;

sub new {  return bless( {}, $_[0] ); }

sub do_stuff {
    return __PACKAGE__ . ' is doing stuff';
}

sub multi_stuff {
    return __PACKAGE__ . ' is doing multi-stuff';
}

sub priority { return 1; }

1;
