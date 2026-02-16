use v5.36;
use lib ".";

use Test::More;
use Test::Exception;

use Geometry3;
use Material;

use constant {
    MAT_BORDER => 1,
    MAT_TEXT   => 2,
};

subtest 'constructor validation' => sub {
    throws_ok { Material::new() }
        qr/geometry is required/,
        'missing geometry dies';

    my $geo = Geometry3::from_str("abc");

    throws_ok { Material::new($geo) }
        qr/classify must be a CODE reference/,
        'missing classifier dies';

    lives_ok {
        Material::new($geo, sub { MAT_TEXT })
    } 'valid constructor lives';
};

subtest 'simple material classification' => sub {
    my $geo = Geometry3::from_str(<<'EOF');
+-+
|a|
+-+
EOF

    my $mat = Material::new(
        $geo,
        sub ($pos, $ch, $geo) {
            return MAT_BORDER if $ch =~ /[+\-|]/;
            return MAT_TEXT;
        }
    );

    ok($mat->isa('Material'), 'material object created');

    my $spans = $mat->spans;
    ok(@$spans > 0, 'spans generated');

    for my $s (@$spans) {
        my ($pos, $glyphs, $material) = @$s;
        ok(defined $material, 'material defined');
    }
};

subtest 'span splitting on material boundary' => sub {
    my $geo = Geometry3::from_str("+-a-+");

    my $mat = Material::new(
        $geo,
        sub ($pos, $ch, $geo) {
            return MAT_BORDER if $ch ne 'a';
            return MAT_TEXT;
        }
    );

    my $spans = $mat->spans;

    is(scalar @$spans, 3, 'geometry split into 3 spans');

    is($spans->[0][1], '+-', 'left border span');
    is($spans->[1][1], 'a',  'text span');
    is($spans->[2][1], '-+', 'right border span');

    is($spans->[0][2], MAT_BORDER, 'border material');
    is($spans->[1][2], MAT_TEXT,   'text material');
};

done_testing;
