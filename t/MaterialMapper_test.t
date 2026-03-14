use v5.36;
use Test::More;
use Test::Exception;

use lib '.';
use MaterialMapper;
use TerminalStyle;

subtest 'constructor' => sub {
    dies_ok { MaterialMapper::from_callback(undef) } 'missing mapper';
    dies_ok { MaterialMapper::from_callback({}) } 'non-coderef mapper';
};

subtest 'style mapping' => sub {
    my $mat = MaterialMapper::from_callback(sub ($material) {
        return { -fg => 0xff00ff } if $material eq 'MAGENTA';
        return { -bg => 0x000000, -attrs => 3 } if $material eq 'HIGHLIGHT';
        return undef;
    });

    isa_ok($mat->style('MAGENTA'), 'TerminalStyle');
    is_deeply({ %{$mat->style('MAGENTA')} }, { -fg => 0xff00ff }, 'returns fg only');
    is_deeply({ %{$mat->style('HIGHLIGHT')} }, { -bg => 0x000000, -attrs => 3 }, 'returns bg+attrs');
    ok(!defined($mat->lookup('UNKNOWN')), 'lookup returns undef for unknown material');
    dies_ok { $mat->style('UNKNOWN') } 'invalid material';

    my $via_overload = $mat->('MAGENTA');
    isa_ok($via_overload, 'TerminalStyle');
    is_deeply({ %$via_overload }, { -fg => 0xff00ff }, 'callable overload');
};

subtest 'style normalization' => sub {
    my $mat = MaterialMapper::from_callback(sub ($material) {
        return { -fg => 1, foo => 2, -attrs => 3 };
    });
    ok(!defined($mat->lookup('X')), 'invalid style lookup returns undef');
    dies_ok { $mat->style('X') } 'invalid key';
};

subtest 'style normalization and validation' => sub {
    my $style = { -fg => 1, -bg => 2 };
    my $mat = MaterialMapper::from_callback(sub ($material) { $style });
    my $out = $mat->style('X');
    isa_ok($out, 'TerminalStyle');
    is_deeply({ %$out }, { -fg => 1, -bg => 2 }, 'style hash normalized');

    my $bad = MaterialMapper::from_callback(sub ($material) { [] });
    ok(!defined($bad->lookup('X')), 'non-hashref lookup returns undef');
    dies_ok { $bad->style('X') } 'non-hashref style';

    my $direct = TerminalStyle::new(-attrs => 7);
    my $direct_mat = MaterialMapper::from_callback(sub ($material) { $direct });
    is($direct_mat->style('X'), $direct, 'TerminalStyle return is preserved');
};

done_testing;
