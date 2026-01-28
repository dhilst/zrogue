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

sub v($x,$y) { Matrix3::Vec::from_xy($x, $y) }

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

sub render_text($at_vec, $text, $term, %opts) {
    use integer;
    $opts{-justify} //= 'left';
    if ($opts{-justify} eq 'center') {
        my $T = Matrix3::translate(- length($text) / 2, 0);
        $term->write_vec($text, $at_vec * $T * $terminal_space);
        return;
    } elsif ($opts{-justify} eq 'right') {
        my $T = Matrix3::translate(- length($text), 0);
        $term->write_vec($text, $at_vec * $T * $terminal_space);
        return;
    }


    $term->write_vec($text, $at_vec * $terminal_space);
}


my $inventory = Geometry3::from_str($Views::INVENTORY, -centerfy => 1);
render_geometry($origin, $inventory, $term);
render_text($inventory->points->{NAME}, "LEON ", $term);
render_text($inventory->points->{FILE}, "> FILE", $term);
render_text($inventory->points->{MAP}, "> MAP", $term);
render_text($inventory->points->{ITEM}, "> ITEM", $term);
render_text($inventory->points->{EXIT}, "> EXIT", $term);
render_text($inventory->points->{HAND}, "> 9mm Pistol", $term, -justify => 'center');
render_text($inventory->points->{PKT}, "> Lighter", $term, -justify => 'center');
render_text($inventory->regions->{HEALTH}->bottomright, "Fine", $term, -justify => 'right');
render_text($inventory->regions->{STATUS}->center, "Some item image here", $term, -justify => 'center');
render_text($inventory->regions->{TEXT}->center, "Some item text description here", $term, -justify => 'center');
render_text($inventory->regions->{INVENTORY}->topleft, "List of items in invetory", $term,);
