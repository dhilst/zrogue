use v5.36;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'ZTUI',
    VERSION_FROM => 'lib/ZTUI.pm',
    ABSTRACT => 'Perl terminal UI and rendering toolkit',
    LICENSE      => 'perl',
    AUTHOR       => 'ZTUI contributors',
    MIN_PERL_VERSION => '5.036',
    EXE_FILES    => [],
    PREREQ_PM    => {
        'AnyEvent'      => 0,
        'EV'            => 0,
        'Math::MatrixReal' => 0,
    },
    TEST_REQUIRES => {
        'Test::More'      => 0,
        'Test::Exception' => 0,
    },
);
