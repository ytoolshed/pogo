use CGI;
use Apache2::Reload;
use Log::Log4perl qw(:easy);
use YAML::XS qw(LoadFile);

use lib qw(/Users/nrh/projects/pogo/lib);
use Pogo::Engine;

Log::Log4perl::init_once('/usr/local/etc/pogo/api/log4perl.conf');

my $conf;
eval { $conf = LoadFile( $opts->{conf} ); };

if ($@)
{
  LOGDIE "couldn't open config: $@\n";
}

Pogo::Engine->init($conf);

CGI->compile(':all');

INFO "hello, world!";

1;

