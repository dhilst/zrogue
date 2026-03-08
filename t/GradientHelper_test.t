use v5.36;
use Test::More;
use Test::Exception;

use lib '.';
use GradientHelper;

sub _approx($got, $expected, $eps = 1e-9) {
    abs($got - $expected) <= $eps;
}

subtest 'constructor validation' => sub {
    dies_ok {
        GradientHelper::new(
            start_color => 0x000000,
            end_color => 0xffffff,
        );
    } 'angle is required';

    dies_ok {
        GradientHelper::new(
            angle_deg => 0,
            end_color => 0xffffff,
        );
    } 'start_color is required';

    dies_ok {
        GradientHelper::new(
            angle_deg => 0,
            start_color => 0x000000,
        );
    } 'end_color is required';

    dies_ok {
        GradientHelper::new(
            angle_deg => 'nope',
            start_color => 0x000000,
            end_color => 0xffffff,
        );
    } 'angle must be numeric';

    dies_ok {
        GradientHelper::new(
            angle_deg => 0,
            start_color => -1,
            end_color => 0xffffff,
        );
    } 'start_color range validated';

    my $gradient = GradientHelper::new(
        angle_deg => 0,
        start_color => 0x000000,
        end_color => 0xffffff,
    );
    isa_ok($gradient, 'GradientHelper');
};

subtest 'advance mutates phase and wraps' => sub {
    my $gradient = GradientHelper::new(
        angle_deg => 0,
        start_color => 0x000000,
        end_color => 0xffffff,
        shift => 0.5,
    );

    ok(_approx($gradient->phase, 0), 'starts at phase 0');

    my $ret = $gradient->advance(1.0);
    is($ret, $gradient, 'advance returns self');
    ok(_approx($gradient->phase, 0.5), 'phase advanced');

    $gradient->advance(2.0);
    ok(_approx($gradient->phase, 0.5), 'phase wrapped to [0,1)');
};

subtest 'horizontal interpolation' => sub {
    my $gradient = GradientHelper::new(
        angle_deg => 0,
        start_color => 0xff0000,
        end_color => 0x0000ff,
    );

    is($gradient->color_at_local(0, 0, 3, 1), 0xff0000, 'left edge uses start color');
    is($gradient->color_at_local(2, 0, 3, 1), 0x0000ff, 'right edge uses end color');
    is($gradient->color_at_local(1, 0, 3, 1), 0x800080, 'center is blended');
};

subtest 'vertical interpolation follows bottom-to-top angle convention' => sub {
    my $gradient = GradientHelper::new(
        angle_deg => 90,
        start_color => 0x000000,
        end_color => 0xffffff,
    );

    is($gradient->color_at_local(0, 2, 1, 3), 0x000000, 'bottom maps to start color');
    is($gradient->color_at_local(0, 0, 1, 3), 0xffffff, 'top maps to end color');
};

subtest 'phase shift affects sampled color' => sub {
    my $gradient = GradientHelper::new(
        angle_deg => 0,
        start_color => 0x000000,
        end_color => 0xffffff,
        shift => 0.5,
    );
    $gradient->advance(1.0);

    is($gradient->color_at_local(0, 0, 3, 1), 0x808080, 'phase shift moves gradient');
};

subtest 'color_at_local validates dimensions' => sub {
    my $gradient = GradientHelper::new(
        angle_deg => 0,
        start_color => 0x000000,
        end_color => 0xffffff,
    );

    dies_ok { $gradient->color_at_local(0, 0, 0, 1) } 'w must be positive';
    dies_ok { $gradient->color_at_local(0, 0, 1, 0) } 'h must be positive';
};

done_testing;
