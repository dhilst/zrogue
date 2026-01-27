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
use Termlib;
use Matrix3 qw($REFLECT_X);
use Geometry3;
use Views;
use Viewport;
use Utils qw(aref);

my $term = Termlib->new();

$term->initscr('.');

my $COLS = $term->cols;
my $ROWS = $term->rows;

# Set origin to screen center
my $terminal_space = 
        Matrix3::translate(($COLS - 1)/2, $ROWS/2)
            ->mul_mat_inplace($REFLECT_X);

my $origin = Matrix3::Vec::from_xy(0, 0);
my $terminal_origin =
    $origin->copy->mul_mat_inplace($terminal_space);

sub render_geometry($at_vec, $geo, $term) {
    use integer;
    my $coord_mapper = $terminal_space * Matrix3::translate($at_vec->@*);
    for my $point ($geo->@*) {
        my ($pos_vec, $value) = $point->@*;
        $pos_vec *= $coord_mapper;
        $term->write_vec($value, $pos_vec);
    }
}

sub render_text($at_vec, $text, $term) {
    $term->write_vec($text, $at_vec * $terminal_space);
}

my $hello = Geometry3::from_str(<<'EOF', -centerfy => 1);
,------------------,
|                  |
|     $GREETINGS   |
|                  |
'------------------'
EOF

render_geometry($origin, $hello, $term);
render_text($hello->points->{'$GREETINGS'}, "hello", $term);

