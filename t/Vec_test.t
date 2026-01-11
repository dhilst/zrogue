use v5.36;
use Test::More;
use Test::Exception;

use lib '.';
use Vec;

# ----------------------------
# construction / stringify
# ----------------------------

my $v = Vec->new(1, 2, 3);

is("$v", "(1,2,3)", 'stringification');
is($v->dim, 3, 'dimension');

# ----------------------------
# addition / subtraction
# ----------------------------

my $a = Vec->new(1, 2);
my $b = Vec->new(3, 4);

is_deeply($a + $b, Vec->new(4, 6), 'vector addition');
is_deeply($b - $a, Vec->new(2, 2), 'vector subtraction');
is_deeply(-$a, Vec->new(-1, -2), 'negation');

throws_ok {
    Vec->new(1,2) + Vec->new(1,2,3)
} qr/invalid vec combination/, 'dimension mismatch add';

# ----------------------------
# scalar multiplication
# ----------------------------

is_deeply(
    $a * 3,
    Vec->new(3, 6),
    'scalar multiplication'
);

throws_ok {
    3 * $a
} qr/cannot commute vector mul/, 'scalar must be rhs';

# ----------------------------
# length
# ----------------------------

my $vlen = Vec->new(3, 4);

cmp_ok($vlen->length, '==', 5, 'vector length');

# ----------------------------
# direction (unit)
# ----------------------------

my $unit = $vlen->direction_sqrt;

cmp_ok($unit->length, '>', 0.999, 'unit vector length ≈ 1');
cmp_ok($unit->length, '<', 1.001, 'unit vector length ≈ 1');

# ----------------------------
# direction (gcd)
# ----------------------------

is_deeply(
    Vec->new(6, 9)->direction_gcd,
    Vec->new(2, 3),
    'gcd direction'
);

throws_ok {
    Vec->new(0, 0)->direction_gcd
} qr/0 GCD/, 'gcd zero vector rejected';

# ----------------------------
# direction (chebyshev)
# ----------------------------

is_deeply(
    Vec->new(-5, 0, 7)->direction_chebyshev,
    Vec->new(-1, 0, 1),
    'chebyshev direction'
);

# ----------------------------
# dot product
# ----------------------------

is(
    Vec->new(1,2,3)->dot(Vec->new(4,5,6)),
    32,
    'dot product'
);

throws_ok {
    Vec->new(1,2)->dot(Vec->new(1))
} qr/dimension mismatch/, 'dot dimension mismatch';

# ----------------------------
# homogeneous helpers
# ----------------------------

is_deeply(
    Vec->new(1,2)->as_point,
    Vec->new(1,2,1),
    'as_point'
);

is_deeply(
    Vec->new(1,2)->as_dir,
    Vec->new(1,2,0),
    'as_dir'
);

# swapped subtraction path (this exposes the bug)
is_deeply(
    $a->sub($b, 1),
    Vec->new(2, 2),
    'b - a works (swap path)'
);

done_testing;
