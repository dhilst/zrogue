use v5.36;
use utf8;
use Test::More;

use lib '.';
use Viewport;
use Matrix3;

# helper
sub vect($x,$y) { Matrix3::Vec::from_xy($x,$y) }

# ------------------------------------------------------------
# from_pos_hw
# ------------------------------------------------------------

subtest 'from_pos_hw basic geometry' => sub {
    my $pos = vect(10, 20);
    my $h = 5;
    my $w = 7;

    my $vp = Viewport::from_pos_hw($pos, $h, $w);

    ok($vp, 'viewport created');
    isa_ok($vp, 'Viewport');

    is($vp->h, $h, 'height stored');
    is($vp->w, $w, 'width stored');

    # corners
    is($vp->topleft,     vect(10, 20), 'topleft correct');
    is($vp->topright,    vect(16, 20), 'topright correct');
    is($vp->bottomleft,  vect(10, 24), 'bottomleft correct');
    is($vp->bottomright, vect(16, 24), 'bottomright correct');

    # center: ((w-1)/2, (h-1)/2) = (3,2)
    is(
        $vp->center,
        vect(13, 22),
        'center correct'
    );
};

# ------------------------------------------------------------
# move
# ------------------------------------------------------------

subtest 'move applies transform to all points' => sub {
    my $pos = vect(0, 0);
    my $vp = Viewport::from_pos_hw($pos, 3, 3);

    my $move = Matrix3::translate(5, -2);
    $vp->move($move);

    is($vp->topleft,     vect(5, -2),  'topleft moved');
    is($vp->topright,    vect(7, -2),  'topright moved');
    is($vp->bottomleft,  vect(5,  0),  'bottomleft moved');
    is($vp->bottomright, vect(7,  0),  'bottomright moved');
    is($vp->center,      vect(6, -1),  'center moved');
};

# ------------------------------------------------------------
# immutability of input vecttor
# ------------------------------------------------------------

subtest 'from_pos_hw does not mutate input vecttor' => sub {
    my $pos = vect(1, 2);
    Viewport::from_pos_hw($pos, 3, 3);

    is($pos, vect(1,2), 'input position unchanged');
};

done_testing;
