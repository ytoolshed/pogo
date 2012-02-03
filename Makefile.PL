use ExtUtils::MakeMaker;
my $meta_merge = {
    META_MERGE => {
        resources => {
            repository => 'http://github.com/ytoolshed/pogo',
        },
    }
};
WriteMakefile(
    'NAME'         => 'Pogo',
    'VERSION_FROM' => 'lib/Pogo.pm', # finds $VERSION
    'PREREQ_PM'    => {
        JSON => 2.53,
    }, # e.g., Module::Name => 1.1
    $ExtUtils::MakeMaker::VERSION >= 6.50 ? (%$meta_merge) : (),
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/Pogo.pm',
       AUTHOR     => 'Mike Schilli <m@perlmeister.com>') : ()),
);
