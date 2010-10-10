use CGI;
use Apache2::Reload;
use Log::Log4perl qw(:easy);

use lib qw(/Users/nrh/projects/pogo/lib);
use Pogo::Engine;

Log::Log4perl::init_once('/usr/local/etc/pogo/api/log4perl.conf');
Pogo::Engine->init( conf => '/usr/local/etc/pogo/pogo.conf');

CGI->compile(':all');

INFO "hello, world!";


1;

