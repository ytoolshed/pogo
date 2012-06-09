
use Log::Log4perl qw(:easy);
use Getopt::Std;

getopts( "v", \my %opts );

if( $opts{ v } ) {
    Log::Log4perl->easy_init({ level => $DEBUG, layout => "%F{2}-%L: %m%n" });
    DEBUG "Verbose mode";
}

1;
