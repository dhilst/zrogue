use v5.36;
use Test::More;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use ZTUI::TerminalStyle;

subtest 'constructor stores provided values' => sub {
    my $style = ZTUI::TerminalStyle::new(
        -fg => 0x112233,
        -bg => 0x445566,
        -attrs => 7,
    );

    isa_ok($style, 'ZTUI::TerminalStyle');
    is($style->fg, 0x112233, 'fg stored');
    is($style->bg, 0x445566, 'bg stored');
    is($style->attrs, 7, 'attrs stored');
};

subtest 'constructor allows omitted keys' => sub {
    my $style = ZTUI::TerminalStyle::new(-fg => 0xffffff);

    is($style->fg, 0xffffff, 'fg stored');
    ok(!defined($style->bg), 'bg omitted');
    ok(!defined($style->attrs), 'attrs omitted');
};

subtest 'constructor validates keys and values' => sub {
    dies_ok { ZTUI::TerminalStyle::new(foo => 1) } 'unknown key dies';
    dies_ok { ZTUI::TerminalStyle::new(-fg => 0x1000000) } 'fg out of rgb range dies';
    dies_ok { ZTUI::TerminalStyle::new(-bg => -2) } 'bg below sentinel dies';
    dies_ok { ZTUI::TerminalStyle::new(-attrs => 1.5) } 'attrs must be integer';
};

subtest 'sentinel colors are allowed' => sub {
    my $style = ZTUI::TerminalStyle::new(
        -fg => -1,
        -bg => -1,
    );

    is($style->fg, -1, 'fg sentinel stored');
    is($style->bg, -1, 'bg sentinel stored');
};

subtest 'from_hashref normalizes existing style hash' => sub {
    my $style = ZTUI::TerminalStyle::from_hashref({
        -fg => 0xaabbcc,
        -attrs => 3,
    });

    isa_ok($style, 'ZTUI::TerminalStyle');
    is($style->fg, 0xaabbcc, 'fg copied from hash');
    is($style->attrs, 3, 'attrs copied from hash');
    ok(!defined($style->bg), 'missing bg remains undefined');
};

subtest 'from_hashref rejects invalid input' => sub {
    dies_ok { ZTUI::TerminalStyle::from_hashref([]) } 'non hashref dies';
    dies_ok { ZTUI::TerminalStyle::from_hashref({ nope => 1 }) } 'invalid style hash dies';
};

subtest 'as_hashref returns a fresh normalized hash' => sub {
    my $style = ZTUI::TerminalStyle::new(
        -fg => 0x010203,
        -attrs => 5,
    );

    my $hash = $style->as_hashref;
    is_deeply($hash, {
        -fg => 0x010203,
        -attrs => 5,
    }, 'only defined keys exported');

    $hash->{-fg} = 0xffffff;
    is($style->fg, 0x010203, 'returned hash is detached from object');
};

subtest 'hashref overload exports normalized style hash' => sub {
    my $style = ZTUI::TerminalStyle::new(
        -bg => 0x223344,
        -attrs => 1,
    );

    my %hash = %$style;
    is_deeply(\%hash, {
        -bg => 0x223344,
        -attrs => 1,
    }, 'hashref overload matches style shape');
};

done_testing;
