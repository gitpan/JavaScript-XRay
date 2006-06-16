use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'JavaScript::XRay',
    AUTHOR              => 'Jeff Bisbee <jbisbee@cpan.org>',
    VERSION_FROM        => 'lib/JavaScript/XRay.pm',
    ABSTRACT_FROM       => 'lib/JavaScript/XRay.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'  => 0,
        'Carp'        => 0,
        'LWP::Simple' => 0,
        },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'JavaScript-XRay-*' },
);
