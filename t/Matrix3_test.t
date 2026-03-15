use v5.36;
use Test::More;
use Test::Exception;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use ZTUI::Matrix3;

my $vec = ZTUI::Matrix3::Vec::from_xy(1, 0);
my $cpy = $vec->copy;

$cpy *= $ZTUI::Matrix3::ID;
is_deeply($cpy, $vec);

$cpy = $vec->copy;
$cpy *= $ZTUI::Matrix3::ROT90;
is_deeply($cpy, ZTUI::Matrix3::Vec::from_xy(0, 1));

$cpy = $vec->copy;
$cpy *= $ZTUI::Matrix3::ROT180;
is_deeply($cpy, ZTUI::Matrix3::Vec::from_xy(-1, 0));
 
$cpy = $vec->copy;
$cpy *= $ZTUI::Matrix3::ROT270;
is_deeply($cpy, ZTUI::Matrix3::Vec::from_xy(0, -1));

$cpy = $vec->copy;


done_testing;
