use v5.36;
use Test::More;
use Term::ANSIColor;

use lib '.';
use SGR;

subtest 'attrs works as expected' => sub {
    my @attrs = SGR::attrs(0);

    is_deeply(\@attrs, []);

    is(Term::ANSIColor::color(@attrs), undef);
};

done_testing;
