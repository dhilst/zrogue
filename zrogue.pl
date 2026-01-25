use v5.36;
use utf8;

use Carp;
use Term::Cap;
use Term::ANSIColor;
use Time::HiRes qw(sleep);
use List::Util;
use Data::Dumper;
use Math::BigInt qw(bgcd);
use FindBin qw($Bin);
use Benchmark qw(:all);

use lib "$Bin/vendor/lib/perl5";
use lib "$Bin";

use Vec;
use Matrix;
use Matrix3 qw($REFLECT_X);
use Termlib;
use Geometry;
use Geometry3;
use Views;
use Utils qw(aref);

my $term = Termlib->new();

$term->initscr('.');

my $COLS = $term->cols;
my $ROWS = $term->rows;

# Set origin to screen center
my $origin = Vec->new(0, 0, 1);
my $origin3 = Matrix3::Vec::from_xy(0, 0);

sub render_geometry($at_vec, $geo, $term) {
    state $screen_space =
        Matrix::int 
        Matrix::translate(($COLS - 1) / 2, $ROWS / 2)
        * Matrix::reflect_x()
        ;

    my $translate = $screen_space * Matrix::translate_vec($at_vec);
    for my $point ($geo->@*) {
        my ($pos_vec, $value) = $point->@*;
        $term->write_vec($value, $translate * $pos_vec);
    }
}

sub render_geometry3($at_vec, $geo, $term) {
    use integer;
    my $coord_mapper = 
        Matrix3::translate(($COLS - 1)/2, $ROWS/2)
            ->mul_mat_inplace($REFLECT_X)
            ->mul_mat_inplace(Matrix3::translate($at_vec->@*));

    for my $point ($geo->@*) {
        my ($pos_vec, $value) = $point->@*;
        $term->write_vec($value, $pos_vec->mul_mat_inplace($coord_mapper));
    }
}

my $inventory_geo = Geometry::from_str($Views::INVENTORY, -centerfy => 1);
my $inventory_geo3 = Geometry3::from_str($Views::INVENTORY, -centerfy => 1);

# render_geometry($origin, $square_geo, $term); # works
# render_geometry3($origin, $square_geo3, $term), # does not render the square
# render_geometry($origin, $inventory_geo, $term), # does not render the square
render_geometry3($origin3, $inventory_geo3, $term), # does not render the square
