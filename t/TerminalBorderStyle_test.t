use v5.36;
use Test::More;
use Test::Exception;

use lib '.';
use TerminalBorderStyle;

subtest 'constructor stores provided values' => sub {
    my $style = TerminalBorderStyle::new(
        -fg => 0x112233,
        -bg => 0x445566,
        -attrs => 7,
        -border => ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
    );

    isa_ok($style, 'TerminalBorderStyle');
    is($style->fg, 0x112233, 'fg stored');
    is($style->bg, 0x445566, 'bg stored');
    is($style->attrs, 7, 'attrs stored');
    is_deeply($style->border, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'], 'border stored');
};

subtest 'constructor fills defaults' => sub {
    my $style = TerminalBorderStyle::new();

    is($style->fg, 0xffffff, 'default fg');
    is($style->bg, 0x000000, 'default bg');
    is($style->attrs, 0, 'default attrs');
    is_deeply($style->border, ['+', '-', '+', '|', ' ', '|', '+', '-', '+'], 'default border');
};

subtest 'constructor validates keys and values' => sub {
    dies_ok { TerminalBorderStyle::new(foo => 1) } 'unknown key dies';
    dies_ok { TerminalBorderStyle::new(-fg => 0x1000000) } 'fg out of range dies';
    dies_ok { TerminalBorderStyle::new(-attrs => 1.5) } 'attrs must be integer';
    dies_ok { TerminalBorderStyle::new(-border => 'abc') } 'border must be arrayref';
    dies_ok { TerminalBorderStyle::new(-border => [1 .. 8]) } 'border must have 9 entries';
};

subtest 'border accessor returns a copy' => sub {
    my $style = TerminalBorderStyle::new(
        -border => ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
    );

    my $border = $style->border;
    $border->[0] = 'x';
    is_deeply($style->border, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'], 'stored border is immutable from accessor output');
};

done_testing;
