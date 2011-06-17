package Pogo::Plugin::BadPlugin::NoNewMethod;

# missing new() method

sub do_stuff {
    return __PACKAGE__ . ' is doing stuff';
}

sub priority { return 1; }

1;
