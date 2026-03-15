use v5.36;
use Test::More;
use Test::Exception;
use List::Util;
use Carp;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use ZTUI::Utils;

subtest 'Array utils' => sub {
    is(ZTUI::Utils::Array::index_of(1, (3,2,1)), 2);
    is(ZTUI::Utils::Array::index_of(4, (3,2,1)), -1);

    my @out = ZTUI::Utils::Array::for_batch {
        List::Util::sum(@_)
    } 2, [1,2,3,4,5,6,7,8];

    is_deeply(\@out, [3,7,11,15]);

    my @nested = ([1,2,3],[4,5,6]);
    my @flat = ZTUI::Utils::Array::flatten(@nested);
    is_deeply(\@flat, [1,2,3,4,5,6]);

};

done_testing;
