use v5.36;
use Test::More;
use Test::Exception;

use lib '.';
use Vec;
use Matrix3;

my $vec = Matrix3::Vec::from_xy(1, 0);
my $cpy = $vec->copy;

$cpy *= $Matrix3::ID;
is_deeply($cpy, $vec);

$cpy = $vec->copy;
$cpy *= $Matrix3::ROT90;
is_deeply($cpy, [0, 1]);

$cpy = $vec->copy;
$cpy *= $Matrix3::ROT180;
is_deeply($cpy, [-1, 0]);
 
$cpy = $vec->copy;
$cpy *= $Matrix3::ROT270;
is_deeply($cpy, [0, -1]);

$cpy = $vec->copy;


done_testing;

