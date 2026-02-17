use v5.36;
use Test::More;
use Test::Exception;
use Data::Dumper;

use lib ".";
use Buffer2D;


subtest 'single cell diff' => sub {
    # Back buffer holds the rendering frame
    my $back = Buffer2D::new("l3", 3, 4, [0,0,0], -autoclip => 0);
    # Front buffer holds what is in the screen
    my $front = $back->copy;
    $back->set(0, 0, [0,2,3]);

    is_deeply(
        [$back->diff($front)],
        [{ col => 0, row => 0, payload => [0,2,3], size => 1 }],
        'diff returns single updated cell'
    );

    $front->sync($back);
};

subtest 'multiple independent updates' => sub {
    # Back buffer holds the rendering frame
    my $back = Buffer2D::new("l3", 3, 4, [0,0,0], -autoclip => 0);
    # Front buffer holds what is in the screen
    my $front = $back->copy;
    $back->set(0, 0, [1,0,0]);
    $back->set(2, 2, [9,0,8]);

    my @delta = $back->diff($front);
    is_deeply(
        \@delta,
        [
            { payload => [1,0,0], col => 0, row => 0, size => 1 },
            { payload => [9,0,8], col => 2, row => 2, size => 1 },
        ],
        'diff returns multiple independent updates'
    );
};

subtest 'last write wins' => sub {
    # Back buffer holds the rendering frame
    my $back = Buffer2D::new("l3", 3, 4, [0,0,0], -autoclip => 0);
    # Front buffer holds what is in the screen
    my $front = $back->copy;
    $back->set(1, 0, [1,1,1]);
    $back->set(1, 0, [2,2,2]);

    is_deeply(
        [$back->diff($front)],
        [
            { payload => [2,2,2], col => 1, row => 0, size => 1 },
        ],
        'only last write is reported'
    );

    $front->sync($back);
};

subtest 'no-op update produces no diff' => sub {
    # Back buffer holds the rendering frame
    my $back = Buffer2D::new("l3", 3, 4, [0,0,0], -autoclip => 0);
    # Front buffer holds what is in the screen
    my $front = $back->copy;
    $back->set(1, 0, [0,0,0]);

    is_deeply(
        [$back->diff($front)],
        [],
        'no diff when buffer matches front'
    );

    $front->sync($back);
};

subtest 'set_multi and updated payload diff' => sub {
    # Back buffer holds the rendering frame
    my $back = Buffer2D::new("l3", 3, 4, [0,0,0], -autoclip => 0);
    # Front buffer holds what is in the screen
    my $front = $back->copy;

    $back->set_multi(0, 0, [1,2,3], [4,5,6]);

    is_deeply(
        [ $back->get_multi(0, 0, 2) ],
        [[1,2,3], [4,5,6]],
        'get_multi returns correct values'
    );

    my @diff = $back->diff($front);

    is_deeply(
        \@diff,
        [{
            payload => [1,2,3,4,5,6],
            size    => 2,
            row     => 0,
            col     => 0
        }],
        'contiguous payloads are updated'
    );

    is(($diff[0]->{payload}->@* / $diff[0]->{size}), 3,
        "step size == lenght / size");
};

subtest 'bounds checking and exceptions' => sub {
    my $H = 3, my $W = 4;
    my $back = Buffer2D::new("l3", $H, $W, [0,0,0]);
    dies_ok  { $back->set(5, 0, [1,1,1]) }      'set out of bounds dies';
    dies_ok  { $back->get(5, 0) }               'get out of bounds dies';
    lives_ok { $back->set(3, 0, [1,2,3]) }      'set at boundary lives';
    lives_ok { $back->set_multi(3, 0, [1,2,3]) }'set_multi single at boundary lives';
    dies_ok  { $back->set_multi(3, 0, [1,2,3], [4,5,6]) }
                                                   'set_multi overflow dies';
    lives_ok { $back->get_multi(3, 0, 1) }      'get_multi single lives';
    dies_ok  { $back->get_multi(3, 0, 2) }      'get_multi overflow dies';
    dies_ok  { $back->set_multi(0, 0) }         'set_multi zero-length dies';
};

subtest 'partial updates works as expected' => sub {
    my $back = Buffer2D::new("l3", 3, 4, [0,0,0]);

    $back->set_multi(0, 0, [1,0,0], [1,0,0]); 
    is_deeply([ $back->get(0, 0) ], [1,0,0]);

    $back->update_multi(0, 0, [undef, 1, undef], [undef, undef, 1]);
    my @payload = $back->get_multi(0, 0, 2); 
    is_deeply(\@payload, [
        [1,1,0], [1,0,1]
    ]);

    $back->update(0, 0, [undef, undef, 2]);
    @payload = $back->get_multi(0, 0, 2); 
    is_deeply(\@payload, [
        [1,1,2], [1,0,1]
    ]);

};

subtest 'clip works as expected' => sub {
    my $H = 3, my $W = 4;
    my $back = Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);

    is_deeply([ $back->clip( 0,  0,    1  ) ], [   0  ,    0  ,    1  ],  "no cliping = nop");
    is_deeply([ $back->clip(-1,  0,    1  ) ], [   0  ,    0  ,    0  ],  "negative col offscreen");
    is_deeply([ $back->clip(-1,  0,    2  ) ], [   0  ,    0  ,    1  ],  "negative col clipping");
    is_deeply([ $back->clip( 0,  0, $W + 1) ], [   0  ,    0  ,   $W  ],  "positive col clipping");
    is_deeply([ $back->clip( 0, -1,    1  ) ], [   0  ,    0  ,    0  ],  "negative row offscreen");
    is_deeply([ $back->clip( 0, $H,    1  ) ], [   0  , $H - 1,    0  ],  "positive row offscreen");

    $back->set_multi(-1, 0, [1,1,1],[2,2,2]);
    is_deeply([ $back->get(0, 0) ], [2,2,2], "offscreen writes are discarted");
};

subtest 'autoclip off-screen writes are ignored' => sub {
    my $H = 3, my $W = 4;

    my $back = Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set(-1, 0, [1,1,1]);
    is_deeply([ $back->get(0, 0) ], [0,0,0], "offscreen left single ignored");

    $back = Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set($W, 0, [1,1,1]);
    is_deeply([ $back->get($W - 1, 0) ], [0,0,0], "offscreen right single ignored");

    $back = Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set(0, -1, [1,1,1]);
    is_deeply([ $back->get(0, 0) ], [0,0,0], "offscreen row above ignored");

    $back = Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set(0, $H, [1,1,1]);
    is_deeply([ $back->get(0, $H - 1) ], [0,0,0], "offscreen row below ignored");

    $back = Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set_multi($W - 1, 0, [3,3,3], [4,4,4]);
    is_deeply([ $back->get($W - 1, 0) ], [3,3,3], "right edge clip keeps visible");

    $back = Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set_multi(-3, 0, [5,5,5], [6,6,6]);
    is_deeply([ $back->get(0, 0) ], [0,0,0], "fully offscreen left ignored");
};

done_testing;
