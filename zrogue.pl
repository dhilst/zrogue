use v5.36;

local $| = 1;

use Carp;
use Term::Cap;
use Term::ANSIColor;
use Time::HiRes qw(sleep);
use List::Util;
use Data::Dumper;
use Math::BigInt qw(bgcd);

use lib ".";

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
