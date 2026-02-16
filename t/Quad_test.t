use v5.36;
use Test::More;

use lib '.';
use Matrix3;
use Quad;

sub vec_is($vec, $x, $y, $label) {
    my $eps = 1e-9;
    ok(abs($vec->x - $x) < $eps, "$label x");
    ok(abs($vec->y - $y) < $eps, "$label y");
}

subtest 'quad accessors works' => sub {
    my $quad = Quad::from_wh(4.5, 2.25);

    vec_is($quad->topleft, 0.0, 0.0, 'topleft');
    vec_is($quad->topright, 4.5, 0.0, 'topright');
    vec_is($quad->bottomleft, 0.0, -2.25, 'bottomleft');
    vec_is($quad->bottomright, 4.5, -2.25, 'bottomright');
    vec_is($quad->center, 2.25, -1.125, 'center');
    ok(abs($quad->width - 4.5) < 1e-9, 'width');
    ok(abs($quad->height - 2.25) < 1e-9, 'height');
};

done_testing;
