use v5.36;
use Test::More;
use Test::Exception;

use lib '.';
use Vec;
use Matrix;

# ----------------------------
# construction / stringify
# ----------------------------

my $m = Matrix::from_str(<<'EOF');
1 2
3 4
EOF

is("$m", "| 1  2|\n| 3  4|", 'matrix stringification');

is($m->rows, 2, 'row count');
is($m->cols, 2, 'column count');

is_deeply($m->column(0), Vec->new(1, 3), "column 0 works");
is_deeply($m->column(1), Vec->new(2, 4), "column 1 works");
dies_ok { $m->column(2) } "column invalid fails";

# ----------------------------
# matrix × vector
# ----------------------------

my $v = Vec->new(10, 20);

my $out = $m->mul_vec($v);

is_deeply(
    $out,
    Vec->new(50, 110),
    'matrix × vector'
);

# ----------------------------
# translation 
# ----------------------------

my $p = Vec->new(2, 3, 1);

my $t = Matrix::translate(5, -2);

is_deeply(
    $t * $p,
    Vec->new(7, 1, 1),
    'translation by (5, -2)'
);

# ----------------------------
# rotation
# ----------------------------

my $p2 = Vec->new(1, 0, 1);

is_deeply(
    Matrix::rot(0) * $p2,
    $p2,
    'rotation 0° is identity'
);

is_deeply(
    Matrix::rot(90) * $p2,
    Vec->new(0, 1, 1),
    'rotation 90° CCW'
);

is_deeply(
    Matrix::rot(180) * $p2,
    Vec->new(-1, 0, 1),
    'rotation 180°'
);

is_deeply(
    Matrix::rot(270) * $p2,
    Vec->new(0, -1, 1),
    'rotation 270° CCW'
);

# ----------------------------
# invalid rotation
# ----------------------------

throws_ok {
    Matrix::rot(45) * $p2;
} qr/invalid deg/, 'invalid rotation rejected (only 90 deg is accepted)';


# ----------------------------
# reflection
# ----------------------------

$p = Vec->new(3, -4, 1);

is_deeply(
    Matrix::reflect_x() * $p,
    Vec->new(3, 4, 1),
    'reflect across X axis'
);

is_deeply(
    Matrix::reflect_y() * $p,
    Vec->new(-3, -4, 1),
    'reflect across Y axis'
);

# direction vectors unaffected by translation component
$v = Vec->new(3, 4, 0);

is_deeply(
    Matrix::reflect_x() * $v,
    Vec->new(3, -4, 0),
    'Matrix::reflect_x on direction vector'
);

is_deeply(
    Matrix::reflect_y() * $v,
    Vec->new(-3, 4, 0),
    'Matrix::reflect_y on direction vector'
);

# involution: reflect twice = identity
is_deeply(
    Matrix::reflect_x() * Matrix::reflect_x() * $p,
    $p,
    'double Matrix::reflect_x is identity'
);

is_deeply(
    Matrix::reflect_y() * Matrix::reflect_y() * $p,
    $p,
    'double Matrix::reflect_y is identity'
);

# matrix multiplication
is_deeply(
    Matrix::rot(90) * Matrix::rot(90),
    Matrix::rot(180)
);

is_deeply(
    Matrix::rot(90) * Matrix::rot(180),
    Matrix::rot(270)
);

is_deeply(
    Matrix::rot(90) * Matrix::rot(270),
    Matrix::rot(0)
);

done_testing;

