package PogoLiveTest;

if( ! exists $ENV{POGO_URL} ) {
    die "Whoa! No POGO_URL set.";
}

if( $ENV{POGO_URL} !~ m#^http://# ) {
    die "Whoa! That's not a valid POGO_URL: $ENV{POGO_URL}";
}

1;
