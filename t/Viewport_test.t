use v5.36;
use utf8;
use Test::More;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use ZTUI::Viewport;
use ZTUI::Matrix3;

# helper
sub vect($x,$y) { ZTUI::Matrix3::Vec::from_xy($x,$y) }

# ------------------------------------------------------------
# from_pos_hw
# ------------------------------------------------------------

subtest 'from_pos_hw basic geometry' => sub {
    my $pos = vect(0, 0);
    my $h = 2;
    my $w = 3;

    my $vp = ZTUI::Viewport::from_pos_hw($pos, $h, $w);

    ok($vp, 'viewport created');
    isa_ok($vp, 'ZTUI::Viewport');

    is($vp->h, $h, 'height stored');
    is($vp->w, $w, 'width stored');

    # corners
    is($vp->topleft,     vect(0,  0), 'topleft correct');
    is($vp->topright,    vect(2,  0), 'topright correct');
    is($vp->bottomleft,  vect(0, -1), 'bottomleft corret');
    is($vp->bottomright, vect(2, -1), 'bottomright corret');
    is($vp->center,      vect(1, -1), 'bottomright corret');
};

# ------------------------------------------------------------
# move
# ------------------------------------------------------------

subtest 'move applies transform to all points' => sub {
    my $pos = vect(0, 0);
    my $vp = ZTUI::Viewport::from_pos_hw($pos, 3, 9);

    my $move = ZTUI::Matrix3::translate(1, 1);
    $vp->move($move);
    is($vp->topleft,     vect(1, 1),  'topleft moved');
    is($vp->topright,    vect(9, 1),  'topright moved');
    is($vp->bottomleft,  vect(1,  -1),  'bottomleft moved');
    is($vp->bottomright, vect(9,  -1),  'bottomright moved');
    is($vp->center,      vect(5, 0),  'center moved');
};

# ------------------------------------------------------------
# immutability of input vecttor
# ------------------------------------------------------------

subtest 'from_pos_hw does not mutate input vecttor' => sub {
    my $pos = vect(1, 2);
    ZTUI::Viewport::from_pos_hw($pos, 3, 3);

    is($pos, vect(1,2), 'input position unchanged');
};

done_testing;
