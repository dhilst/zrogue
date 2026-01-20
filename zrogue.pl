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
use Geometry;
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

sub render_geometry($at_vec, $geo, $term) {
    my $translate = Matrix::translate_vec($at_vec);
    for my $point ($geo->@*) {
        my ($pos_vec, $value) = $point->@*;
        $term->write_vec($value, $screen_space * $translate * $pos_vec);
    }
}

my $circle = Geometry::from_str(<<'EOF', -centerfy => 1);
..xxxxxxxxx..
.x.........x.
x...........x
x...........x
x...........x
x...........x
x...........x
.x.........x.
..xxxxxxxxx..
EOF

my $square = Geometry::from_str(<<'EOF', -centerfy => 1);
xxxxxxxxx
x       x
x       x
x       x
xxxxxxxxx
EOF

my $triangle = Geometry::from_str(<<'EOF', -centerfy => 1);
..x..
.x x.
xxxxx
EOF

my $heart = Geometry::from_str(<<'EOF', -centerfy => 1);
..xxx...xxx..
.x    x    x.
x           x
x           x
.x         x.
...x     x...
.....x x.....
......x......
EOF

my $arrow = Geometry::from_str(<<'EOF', -centerfy => 1);
.......
==>.<==
.......
EOF

sub counter($value) {
    Geometry::from_str(<<"EOF", -centerfy => 1);
Counter: $value
EOF
}

$term->write_vec('O', $screen_space * Vec->new(0, 0, 1));
render_geometry(Vec->new(-15, -6, 1), $square, $term);
render_geometry(Vec->new(-10, -10, 1), $heart, $term);
render_geometry(Vec->new(-10, 10, 1), counter(0), $term);
sleep 0.3;
render_geometry(Vec->new(-10, 10, 1), counter(1), $term);
# render_geometry(Vec->new(0, 0, 1), $triangle, $term);
# render_geometry(Vec->new(10, 20, 1), $triangle, $term);
# render_geometry(Vec->new(10, 20, 1), $triangle, $term);

# $term->write_vec('@', $screen_space * Vec->new(-20, 11, 1));
# render_geometry(Vec->new(-20, 11, 1), $arrow, $term);
#
my () = <<'EOF';
.----------------------------------------------------------------------------------------------------------------------.
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
|                                                                                                                      |
'----------------------------------------------------------------------------------------------------------------------'

EOF

my () = <<'EOF';
╔═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                                         TUI UNICODE CHEAT SHEET                                                         ║
╠═════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════
║ BOX DRAWING                     ║ BLOCK ELEMENTS ║║ SHAPES / UI            ║ ARROWS                ║ STATUS / SYMBOLS ║ BARS / METERS   ║
║ ─ ━ │ ┃ ┄ ┅ ┆ ┇ ┈ ┉ ┊ ┋         ║ ░ ▒ ▓ █ ▄ ▀ ▌ ▐║║ ● ○ ◎ ◉ ◌ ◍ ◐ ◑ ◒ ◓ ◔ ◕║ ← ↑ → ↓ ↔ ↕ ⇐ ⇑ ⇒ ⇓ ⇔ ║ ✓ ✔ ✗ ✘ ✕ ☑ ☒ ☓  ║ ▁ ▂ ▃ ▄ ▅ ▆ ▇ █ ║
║ ┌ ┐ └ ┘ ┍ ┎ ┏ ┑ ┒ ┓ ┕ ┖ ┗ ┙ ┚ ┛ ║ ▁ ▂ ▃ ▄ ▅ ▆ ▇ █║║ ■ □ ▢ ▣ ▤ ▥ ▦ ▧ ▨ ▩    ║ ↖ ↗ ↘ ↙ ⤴ ⤵ ↩ ↪       ║ ★ ☆ ✪ ✯ ✰        ║                 ║
║ ├ ┝ ┞ ┟ ┠ ┡ ┢ ┣ ┤ ┥ ┦ ┧ ┨ ┩ ┪ ┫ ╠═════════════════║▲ △ ▶ ▷ ▼ ▽ ◀ ◁         ║═══════════════════════║ ☺ ☻ ☹            ║ ▏ ▎ ▍ ▌ ▋ ▊ ▉ █ ║
║ ┬ ┭ ┮ ┯ ┰ ┱ ┲ ┳ ┴ ┵ ┶ ┷ ┸ ┹ ┺ ┻ ║                 ║◆ ◇ ◈ ❖                 ║                       ║ ⚠ ⚡ ⛔          ║                 ║
║ ┼ ┽ ┾ ┿ ╀ ╁ ╂ ╃ ╄ ╅ ╆ ╇ ╈ ╉ ╊ ╋ ║                 ╚════════════════════════╝                       ╚════════════════════════════════════╝
║ ═ ║ ╒ ╓ ╔ ╕ ╖ ╗ ╘ ╙ ╚ ╛ ╜ ╝     ║
║                                 ║
║ ╠ ╣ ╦ ╩ ├ ┤ ┬ ┴                 ║
╚═════════════════════════════════╝

EOF

my () = <<'EOF';
                                                 ┌─────────────────┬─────────────────┬────────────────┬────────────────┐
                                                 │                 │                 │                │                │
──┬─────────────────┐                            │    ▷ !FILE      │     ▷ !MAP      │   ▷ !ITEM      │   ▷ !EXIT      │
▒▒│ $NAME           │                            │                 │                 │                │                │
░░│─────────────────│ ┌──────────────────────────┴─────────────────┼───┬─────────────┴───────────────┬┴────────────────┤ 
  │                 │─│ @HEALTH                                    │   │                             │                 │ 
▒▒│    ██████╗      │ │                                            │ E │                             │                 │ 
░░│    ╚════██╗     │ │                                            │ Q │                             │                 │ 
  │      ▄███╔╝     │ │                                            │ U │          $HAND              │ ▷ $POCKET       │ 
▒▒│      ▀▀══╝      │ │                                            │ I │                             │                 │ 
░░│      ██╗        │ │                                            │ P │                             │                 │ 
──│      ╚═╝        │─│                                    @HEALTH │   │                             │                 │ 
┌─│                 │─┼─────────────────────────┬──────────────────┴───┴──────┬──────────────────────┴─────────────────┤ 
│ │                 │ │ CONDITION               │                             │ @INVENTORY                             │
│ └─────────────────┘ └─────────────────────────┘                             │                                        │
│ @STATUS                                                                     │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                     @STATUS │                                        │
│─────────────────────────────────────────────────────────────────────────────│                                        │
│ @TEXT                                                                       │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                             │                                        │
│                                                                       @TEXT │                             @INVENTORY │
└─────────────────────────────────────────────────────────────────────────────┴────────────────────────────────────────┘
EOF

my () = <<'EOF';
.---------------------------------------------------------------------------------------------------------------------.
|                                                                                                                     |
|                                                                                                                     | 
|                                                                                                                     | 
|                                                                                                                     | 
|                                                                                                                     | 
|                                  ▐▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▌                            |
|                                  ▐ ███████╗██████╗  ██████╗  ██████╗ ██╗   ██╗███████╗ ▌                            | 
|                                  ▐ ╚══███╔╝██╔══██╗██╔═══██╗██╔════╝ ██║   ██║██╔════╝ ▌                            |
|                                  ▐   ███╔╝ ██████╔╝██║   ██║██║  ███╗██║   ██║█████╗   ▌                            |
|                                  ▐  ███╔╝  ██╔══██╗██║   ██║██║   ██║██║   ██║██╔══╝   ▌                            |
|                                  ▐ ███████╗██║  ██║╚██████╔╝╚██████╔╝╚██████╔╝███████╗ ▌                            |
|                                  ▐ ╚══════╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝  ╚═════╝ ╚══════╝ ▌                            |
|                                  ▐▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▌                            |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     | 
|                                                                                                                     | 
|                                                                                                                     | 
|                                                                                                                     | 
|                                                                                                                     | 
|                                                                                                                     | 
|                                                                                                                     | 
|                                                                                                                     | 
|                                                                                                                     | 
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
|                                     .--------------------------------------------.                                  |
|                                     |                                            |                                  |
|                                     |               > START GAME                 |                                  |
|                                     |                                            |                                  |
|                                     |               > LOAD GAME                  |                                  |
|                                     |                                            |                                  |
|                                     |               > OPTIONS                    |                                  |
|                                     |                                            |                                  |
|                                     |               > CREDITS                    |                                  |
|                                     |                                            |                                  |
|                                     '--------------------------------------------'                                  |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
|                                                                                                                     |
'---------------------------------------------------------------------------------------------------------------------'
EOF
 
 

my $start_banner = Geometry::from_str(<<'EOF', -centerfy => 1);
,-------------------------------------------.
|                ZRogue                     |
|                                           |
|   A zombie roguelike heavily influenced   |
|   by Resident Evil 2. Walk through a sea  |
|   of zombies, try to find key items to    |
|   unlock new areas an progress in the     |
|   game.                                   |
|                                           |
|                                           |
|                                           |
|                                           |
|                                           |
|                                           |
|                                           |
|         Press Enter to Start.             |
`-------------------------------------------'
EOF

my $pause_banner = Geometry::from_str(<<'EOF', -centerfy => 1);
,---------------------------------------.
|                Pause                  |
`---------------------------------------'
EOF

