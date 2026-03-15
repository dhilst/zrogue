use v5.36;
use utf8;
use Test::More;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use ZTUI::BorderMapper;
use ZTUI::TerminalBorderStyle;

subtest 'constructor validation' => sub {
    dies_ok { ZTUI::BorderMapper::from_callback(undef) } 'missing callback dies';
    dies_ok { ZTUI::BorderMapper::from_callback({}) } 'non-coderef callback dies';
};

subtest 'string style normalizes to 3x3 chars' => sub {
    my $mapper = ZTUI::BorderMapper::from_callback(sub ($material) {
        return "+-+\n| |\n+-+" if $material eq 'ASCII';
        return undef;
    });

    my $style = $mapper->style('ASCII');
    isa_ok($style, 'ZTUI::TerminalBorderStyle');
    is_deeply($style->border, ['+', '-', '+', '|', ' ', '|', '+', '-', '+'], 'style parsed from multiline string');
};

subtest 'array style normalizes to 3x3 chars' => sub {
    my $mapper = ZTUI::BorderMapper::from_callback(sub ($material) {
        return ['┌─┐', '│ │', '└─┘'];
    });

    my $style = $mapper->style('SINGLE');
    isa_ok($style, 'ZTUI::TerminalBorderStyle');
    is_deeply($style->border, ['┌', '─', '┐', '│', ' ', '│', '└', '─', '┘'], 'style parsed from array rows');
};

subtest 'TerminalBorderStyle return is preserved' => sub {
    my $direct = ZTUI::TerminalBorderStyle::new(
        -fg => 1,
        -bg => 2,
        -attrs => 3,
        -border => ['a', 'b', 'c', 'd', ' ', 'f', 'g', 'h', 'i'],
    );
    my $mapper = ZTUI::BorderMapper::from_callback(sub ($material) {
        return $direct;
    });

    is($mapper->style('FRAME'), $direct, 'TerminalBorderStyle object is preserved');
};

subtest 'invalid styles are rejected' => sub {
    my $bad_rows = ZTUI::BorderMapper::from_callback(sub ($material) {
        return "+-+\n| |";
    });
    ok(!defined($bad_rows->lookup('X')), 'less than 3 rows lookup returns undef');
    dies_ok { $bad_rows->style('X') } 'less than 3 rows dies';

    my $bad_cols = ZTUI::BorderMapper::from_callback(sub ($material) {
        return ['+-+', '||', '+-+'];
    });
    ok(!defined($bad_cols->lookup('X')), 'row without 3 chars lookup returns undef');
    dies_ok { $bad_cols->style('X') } 'row without 3 chars dies';

    my $bad_ref = ZTUI::BorderMapper::from_callback(sub ($material) {
        return {};
    });
    ok(!defined($bad_ref->lookup('X')), 'invalid type lookup returns undef');
    dies_ok { $bad_ref->style('X') } 'invalid type dies';
};

done_testing;
