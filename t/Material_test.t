use v5.36;
use Test::More;
use Test::Exception;

use lib '.';
use Material;

subtest 'constructor' => sub {
    dies_ok { Material::from_callback() } 'missing mapper';
    dies_ok { Material::from_callback({}) } 'non-coderef mapper';
};

subtest 'style mapping' => sub {
    my $mat = Material::from_callback(sub ($material) {
        return { -fg => 0xff00ff } if $material eq 'MAGENTA';
        return { -bg => 0x000000, -attrs => 3 } if $material eq 'HIGHLIGHT';
        return undef;
    });

    is_deeply($mat->style('MAGENTA'), { -fg => 0xff00ff }, 'returns fg only');
    is_deeply($mat->style('HIGHLIGHT'), { -bg => 0x000000, -attrs => 3 }, 'returns bg+attrs');
    dies_ok { $mat->style('UNKNOWN') } 'invalid material';

    my $via_overload = $mat->('MAGENTA');
    is_deeply($via_overload, { -fg => 0xff00ff }, 'callable overload');
};

subtest 'style normalization' => sub {
    my $mat = Material::from_callback(sub ($material) {
        return { -fg => 1, foo => 2, -attrs => 3 };
    });
    dies_ok { $mat->style('X') } 'invalid key';
};

subtest 'style copy and validation' => sub {
    my $style = { -fg => 1, -bg => 2 };
    my $mat = Material::from_callback(sub ($material) { $style });
    my $out = $mat->style('X');
    $out->{-fg} = 99;
    is($style->{-fg}, 99, 'style is not copied');

    my $bad = Material::from_callback(sub ($material) { [] });
    dies_ok { $bad->style('X') } 'non-hashref style';
};

done_testing;
