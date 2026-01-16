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
$term->write(0, 0, '@');
$term->write(0, $term->cols, '#');


