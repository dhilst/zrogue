use v5.36;

use Carp;
use Term::Cap;
use Term::ANSIColor;
use Time::HiRes qw(sleep);
use List::Util;
use Data::Dumper;
use Math::BigInt qw(bgcd);
use FindBin qw($Bin);

use lib "$Bin/vendor/lib/perl5";
use lib "$Bin";

use Vec;
use Matrix;
use Termlib;
use Utils qw(aref);

my $term = Termlib->new();

$term->initscr('.');

my $COLS = $term->cols;
my $ROWS = $term->rows;

# Set origin to screen center
my $screen_space =
    Matrix::int 
    Matrix::translate(($COLS - 1) / 2, $ROWS / 2)
    * Matrix::reflect_x()
    ;

# projective coordinate for screen center
my $origin = Vec->new(0, 0, 1);

my $north = Matrix::translate(0, 1);
my $south = Matrix::translate(0, -1);
my $west = Matrix::translate(-1, 0);
my $east = Matrix::translate(1, 0);

$term->write_vec('O', $screen_space * $origin);
$term->write_vec('n', $screen_space * $north * $origin);
$term->write_vec('s', $screen_space * $south * $origin);
$term->write_vec('e', $screen_space * $east  * $origin);
$term->write_vec('w', $screen_space * $west  * $origin);

sub parse($data) { 
    [
        map { [ split //, $_] }
        split /\n/, $data
    ];
}

sub render($pos_vec, $array, $term) {
    my $pos = $pos_vec->copy;
    my ($start_col) = $pos->@*;
    my $width = scalar $array->[0]->@*;
    for my $row ($array->@*) {
        for my $value ($row->@*) {
            $term->write_vec($value, $screen_space * $pos);
            $pos *= $east;
        }
        $pos *= Matrix::translate(-$width, -1);
    }
}

# @TODO
#  Define Space, Viewport, Geometry
#
#  Geometry: a point -> (symbol, attributes) mapping.
#  It defines an object that can be rendered in some space.
#
#  Viewport: a rectangular region of a space and
#    the positon where the rectangle appears in
#    the parent.
#
#    Has an z axis which allow to stack viewports
#    in the same space. Viewports are rendered as
#    if they were stacked in z axis, the covered
#    portion of viewports are not rendered.
#
#  Space: a coordinate system defined in terms of
#    rigid motions of parent's origins. Every space
#    exists inside another space, except Terminal
#    which is the root space. Has no clippling.
#
# Example:
#
#  Terminal viewport (11 x 11, topleft @ origin) <- Terminal space (origin at top left of screen)
#    |
#    `- Screen viewport (11 x 11, topleft @ 5,-5 of Screen space) <- Screen space (origin at 5,5 of Terminal (center of screen))
#        |
#        |- Window A viewport (4 x 3 @ topleft @  4,0 of Screen screen) z = 1 <- Window A space
#        `- Window B viewport (4 x 3 @ topleft @ -3,3 of Screen screen) z = 0 <- Window B space
#
# + : origin
#
# (borders are included in the viewport)
#
#     01234567891
# 0  T+----------  5
# 1   |    ---- |  4
# 2   | ---| A| |  3
# 3   | | B---- |  2
# 4   | ----    |  1
# 5   |   S+    |  0
# 6   |         | -1
# 7   |         | -2
# 8   |         | -3 
# 9   |         | -4
# 1   ----------- -5
#    -54321012345
#    

my $square = <<'EOF';
xxxx
x  x
xxxx
EOF

my $triangle = <<'EOF';
..x..
.x x.
xxxxx
EOF

my $circle = <<'EOF';
.xxx.
x   x
.xxx.
EOF

render(Vec->new(10, 10, 1), parse($square), $term);
render(Vec->new(10, 15, 1), parse($triangle), $term);
render(Vec->new(10, 20, 1), parse($circle), $term);
