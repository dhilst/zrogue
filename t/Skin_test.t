use v5.36;
use Test::More;

use lib ".";
use Geometry3;
use MaterialMapper;
use Skin;

sub cell_at($surface, $x, $y) {
    my $row = -$y;
    [ $surface->buffer->get($x, $row) ];
}

subtest 'skin with shadow' => sub {
    my $mat = MaterialMapper::from_callback(sub ($m) {
        return { -bg => 0 } if $m eq 'DEFAULT';
        return { -bg => 1 } if $m eq 'BG';
        return { -bg => 2 } if $m eq 'SHADOW';
        return {};
    });
    my $geo = Geometry3::from_str("AB\nCD");

    my $surface = Skin::from_geometry($geo,
        -material => $mat,
        -bg => 'BG',
        -shadow => 'SHADOW',
    );

    is($surface->width, 3, 'surface width includes shadow');
    is($surface->height, 3, 'surface height includes shadow');

    is_deeply(cell_at($surface, 0, 0), [ord('A'), -1, 1, -1], 'A cell');
    is_deeply(cell_at($surface, 1, 0), [ord('B'), -1, 1, -1], 'B cell');
    is_deeply(cell_at($surface, 0, -1), [ord('C'), -1, 1, -1], 'C cell');
    is_deeply(cell_at($surface, 1, -1), [ord('D'), -1, 1, -1], 'D cell');

    is_deeply(cell_at($surface, 2, 0), [ord(' '), -1, 0, -1], 'top shadow col default');
    is_deeply(cell_at($surface, 2, -1), [ord(' '), -1, 2, -1], 'right shadow');
    is_deeply(cell_at($surface, 2, -2), [ord(' '), -1, 2, -1], 'bottom right shadow');
    is_deeply(cell_at($surface, 1, -2), [ord(' '), -1, 2, -1], 'bottom shadow');
    is_deeply(cell_at($surface, 0, -2), [ord(' '), -1, 0, -1], 'bottom default');
};

subtest 'skin without shadow' => sub {
    my $mat = MaterialMapper::from_callback(sub ($m) {
        return { -bg => 0 } if $m eq 'DEFAULT';
        return { -bg => 3 } if $m eq 'BG';
        return {};
    });
    my $geo = Geometry3::from_str("X");
    my $surface = Skin::from_geometry($geo, -material => $mat, -bg => 'BG');

    is($surface->width, 1, 'width without shadow');
    is($surface->height, 1, 'height without shadow');
    is_deeply(cell_at($surface, 0, 0), [ord('X'), -1, 3, -1], 'single cell');
};

done_testing;
