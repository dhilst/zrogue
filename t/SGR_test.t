use v5.36;
use Test::More;
use Term::ANSIColor;

use lib '.';
use SGR;

subtest 'attrs works as expected' => sub {
    my @attrs = SGR::attrs(0);

    is_deeply(\@attrs, []);

    my $escape = Term::ANSIColor::color(@attrs);
    ok(!defined($escape) || $escape eq '', 'color() with no attrs is empty');
};

done_testing;
