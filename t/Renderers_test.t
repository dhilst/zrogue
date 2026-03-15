use v5.36;
use Test::More;
use Test::Exception;
use Data::Dumper;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use ZTUI::Buffer2D;
use ZTUI::Matrix3 qw($ID);
use ZTUI::Renderers;
use ZTUI::TerminalStyle;
use ZTUI::TerminalBorderStyle;
use ZTUI::Theme;


subtest 'single cell diff' => sub {
    # Back buffer holds the rendering frame
    my $back = ZTUI::Buffer2D::new("l3", 3, 4, [0,0,0], -autoclip => 0);
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
    my $back = ZTUI::Buffer2D::new("l3", 3, 4, [0,0,0], -autoclip => 0);
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
    my $back = ZTUI::Buffer2D::new("l3", 3, 4, [0,0,0], -autoclip => 0);
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
    my $back = ZTUI::Buffer2D::new("l3", 3, 4, [0,0,0], -autoclip => 0);
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
    my $back = ZTUI::Buffer2D::new("l3", 3, 4, [0,0,0], -autoclip => 0);
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
    my $back = ZTUI::Buffer2D::new("l3", $H, $W, [0,0,0]);
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
    my $back = ZTUI::Buffer2D::new("l3", 3, 4, [0,0,0]);

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
    my $back = ZTUI::Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);

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

    my $back = ZTUI::Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set(-1, 0, [1,1,1]);
    is_deeply([ $back->get(0, 0) ], [0,0,0], "offscreen left single ignored");

    $back = ZTUI::Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set($W, 0, [1,1,1]);
    is_deeply([ $back->get($W - 1, 0) ], [0,0,0], "offscreen right single ignored");

    $back = ZTUI::Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set(0, -1, [1,1,1]);
    is_deeply([ $back->get(0, 0) ], [0,0,0], "offscreen row above ignored");

    $back = ZTUI::Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set(0, $H, [1,1,1]);
    is_deeply([ $back->get(0, $H - 1) ], [0,0,0], "offscreen row below ignored");

    $back = ZTUI::Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set_multi($W - 1, 0, [3,3,3], [4,4,4]);
    is_deeply([ $back->get($W - 1, 0) ], [3,3,3], "right edge clip keeps visible");

    $back = ZTUI::Buffer2D::new("l3", $H, $W, [0,0,0], -autoclip => 1);
    $back->set_multi(-3, 0, [5,5,5], [6,6,6]);
    is_deeply([ $back->get(0, 0) ], [0,0,0], "fully offscreen left ignored");
};

{
    package TestRenderTerm;
    use v5.36;

    sub new() {
        bless {
            batches => [],
            colors => [],
        }, __PACKAGE__;
    }

    sub write_batch($self, $commands) {
        push $self->{batches}->@*, [ map { [ $_->@* ] } $commands->@* ];
    }

    sub write_color($self, $text, $col, $row, $fg, $bg, $attrs) {
        push $self->{colors}->@*, [$text, $col, $row, $fg, $bg, $attrs];
    }
}

{
    package CountingMaterialMapper;
    use v5.36;

    sub new($class, $styles, $classes, $keys) {
        bless {
            styles => $styles,
            classes => $classes,
            keys => $keys,
            calls => {},
        }, $class;
    }

    sub lookup($self, $material) {
        $self->{calls}{$material}++;
        return $self->{styles}{$material};
    }

    sub style($self, $material) {
        return $self->lookup($material);
    }

    sub cache_class($self, $material) {
        return $self->{classes}{$material} // 'STATIC_UNIFORM';
    }

    sub cache_key($self, $dt, $x, $y, $material) {
        my $cb = $self->{keys}{$material};
        return $cb->($dt, $x, $y, $material) if defined $cb;
        return $material;
    }

    sub calls_for($self, $material) {
        return $self->{calls}{$material} // 0;
    }
}

{
    package CountingBorderMapper;
    use v5.36;

    sub new($class, $styles, $classes, $keys) {
        bless {
            styles => $styles,
            classes => $classes,
            keys => $keys,
            calls => {},
        }, $class;
    }

    sub lookup($self, $material) {
        $self->{calls}{$material}++;
        return $self->{styles}{$material};
    }

    sub style($self, $material) {
        return $self->lookup($material);
    }

    sub cache_class($self, $material) {
        return $self->{classes}{$material} // 'STATIC_UNIFORM';
    }

    sub cache_key($self, $dt, $x, $y, $material, $edge) {
        my $cb = $self->{keys}{$material};
        return $cb->($dt, $x, $y, $material, $edge) if defined $cb;
        return join ':', $material, $edge;
    }

    sub calls_for($self, $material) {
        return $self->{calls}{$material} // 0;
    }
}

sub cell($renderer, $col, $row) {
    return [ $renderer->bbuf->get($col, $row) ];
}

sub build_renderer(%opts) {
    my $material_mapper = $opts{material_mapper};
    my $border_mapper = $opts{border_mapper};
    my $theme = ZTUI::Theme::new(
        -material_mapper => $material_mapper,
        -border_mapper => $border_mapper,
    );
    my $renderer = ZTUI::Renderers::DoubleBuffering::new($ID, 8, 12, $theme, ' ');
    $renderer->{term} = TestRenderTerm::new();
    return ($renderer, $theme);
}

subtest 'semantic render_text resolves material through theme' => sub {
    my $material_mapper = CountingMaterialMapper->new({
        DEFAULT => ZTUI::TerminalStyle::new(-fg => 7, -bg => 0, -attrs => 0),
        TITLE => ZTUI::TerminalStyle::new(-fg => 0x112233, -bg => 0x445566, -attrs => 3),
    }, {}, {});
    my $border_mapper = CountingBorderMapper->new({
        DEFAULT => ZTUI::TerminalBorderStyle::new(),
    }, {}, {});
    my ($renderer) = build_renderer(
        material_mapper => $material_mapper,
        border_mapper => $border_mapper,
    );

    $renderer->render_text(ZTUI::Matrix3::Vec::from_xy(1, 2), 'A', -material => 'TITLE');

    is_deeply(cell($renderer, 1, 2), [ord('A'), 0x112233, 0x445566, 3], 'semantic text style resolved into buffer');
    is($material_mapper->calls_for('TITLE'), 1, 'material lookup happened once');
};

subtest 'render_rect fills area using semantic material' => sub {
    my $material_mapper = CountingMaterialMapper->new({
        DEFAULT => ZTUI::TerminalStyle::new(-fg => 7, -bg => 0, -attrs => 0),
        PANEL => ZTUI::TerminalStyle::new(-fg => 10, -bg => 11, -attrs => 12),
    }, {}, {});
    my $border_mapper = CountingBorderMapper->new({
        DEFAULT => ZTUI::TerminalBorderStyle::new(),
    }, {}, {});
    my ($renderer) = build_renderer(
        material_mapper => $material_mapper,
        border_mapper => $border_mapper,
    );

    $renderer->render_rect(ZTUI::Matrix3::Vec::from_xy(2, 4), 3, 2, -material => 'PANEL');

    is_deeply(cell($renderer, 2, 4), [ord(' '), 10, 11, 12], 'top-left fill cell rendered');
    is_deeply(cell($renderer, 4, 3), [ord(' '), 10, 11, 12], 'bottom-right fill cell rendered');
    is($material_mapper->calls_for('PANEL'), 1, 'static uniform rect reused cached style');
};

subtest 'render_border draws glyphs from TerminalBorderStyle' => sub {
    my $material_mapper = CountingMaterialMapper->new({
        DEFAULT => ZTUI::TerminalStyle::new(-fg => 7, -bg => 0, -attrs => 0),
    }, {}, {});
    my $border_mapper = CountingBorderMapper->new({
        DEFAULT => ZTUI::TerminalBorderStyle::new(),
        FRAME => ZTUI::TerminalBorderStyle::new(
            -fg => 1,
            -bg => 2,
            -attrs => 3,
            -border => ['a', 'b', 'c', 'd', ' ', 'f', 'g', 'h', 'i'],
        ),
    }, {}, {});
    my ($renderer) = build_renderer(
        material_mapper => $material_mapper,
        border_mapper => $border_mapper,
    );

    $renderer->render_border(ZTUI::Matrix3::Vec::from_xy(1, 4), 4, 3, -border_material => 'FRAME');

    is_deeply(cell($renderer, 1, 4), [ord('a'), 1, 2, 3], 'top-left border rendered');
    is_deeply(cell($renderer, 2, 4), [ord('b'), 1, 2, 3], 'top edge rendered');
    is_deeply(cell($renderer, 4, 2), [ord('i'), 1, 2, 3], 'bottom-right border rendered');
};

subtest 'static uniform material cache is reused across calls' => sub {
    my $material_mapper = CountingMaterialMapper->new({
        DEFAULT => ZTUI::TerminalStyle::new(-fg => 7, -bg => 0, -attrs => 0),
        STATIC => ZTUI::TerminalStyle::new(-fg => 4, -bg => 5, -attrs => 6),
    }, {
        STATIC => 'STATIC_UNIFORM',
    }, {
        STATIC => sub ($dt, $x, $y, $material) { return 'STATIC'; },
    });
    my $border_mapper = CountingBorderMapper->new({
        DEFAULT => ZTUI::TerminalBorderStyle::new(),
    }, {}, {});
    my ($renderer) = build_renderer(
        material_mapper => $material_mapper,
        border_mapper => $border_mapper,
    );

    $renderer->render_text(ZTUI::Matrix3::Vec::from_xy(0, 0), 'A', -material => 'STATIC');
    $renderer->render_text(ZTUI::Matrix3::Vec::from_xy(5, 5), 'B', -material => 'STATIC');

    is($material_mapper->calls_for('STATIC'), 1, 'static material lookup cached persistently');
};

subtest 'static cellwise material cache respects cache_key' => sub {
    my $material_mapper = CountingMaterialMapper->new({
        DEFAULT => ZTUI::TerminalStyle::new(-fg => 7, -bg => 0, -attrs => 0),
        GRID => ZTUI::TerminalStyle::new(-fg => 9, -bg => 8, -attrs => 7),
    }, {
        GRID => 'STATIC_CELLWISE',
    }, {
        GRID => sub ($dt, $x, $y, $material) { return join ':', $material, $x, $y; },
    });
    my $border_mapper = CountingBorderMapper->new({
        DEFAULT => ZTUI::TerminalBorderStyle::new(),
    }, {}, {});
    my ($renderer) = build_renderer(
        material_mapper => $material_mapper,
        border_mapper => $border_mapper,
    );

    $renderer->render_text(ZTUI::Matrix3::Vec::from_xy(1, 1), 'A', -material => 'GRID');
    $renderer->render_text(ZTUI::Matrix3::Vec::from_xy(1, 1), 'B', -material => 'GRID');
    $renderer->render_text(ZTUI::Matrix3::Vec::from_xy(2, 1), 'C', -material => 'GRID');

    is($material_mapper->calls_for('GRID'), 2, 'cellwise cache key differentiates positions and reuses identical positions');
};

subtest 'dynamic uniform material cache resets after flush' => sub {
    my $material_mapper = CountingMaterialMapper->new({
        DEFAULT => ZTUI::TerminalStyle::new(-fg => 7, -bg => 0, -attrs => 0),
        PULSE => ZTUI::TerminalStyle::new(-fg => 3, -bg => 2, -attrs => 1),
    }, {
        PULSE => 'DYNAMIC_UNIFORM',
    }, {
        PULSE => sub ($dt, $x, $y, $material) { return join ':', $material, $dt; },
    });
    my $border_mapper = CountingBorderMapper->new({
        DEFAULT => ZTUI::TerminalBorderStyle::new(),
    }, {}, {});
    my ($renderer) = build_renderer(
        material_mapper => $material_mapper,
        border_mapper => $border_mapper,
    );

    $renderer->render_text(ZTUI::Matrix3::Vec::from_xy(1, 1), 'A', -material => 'PULSE');
    $renderer->render_text(ZTUI::Matrix3::Vec::from_xy(2, 1), 'B', -material => 'PULSE');
    is($material_mapper->calls_for('PULSE'), 1, 'dynamic uniform cached within a frame');

    $renderer->flush;
    $renderer->render_text(ZTUI::Matrix3::Vec::from_xy(3, 1), 'C', -material => 'PULSE');
    is($material_mapper->calls_for('PULSE'), 2, 'dynamic uniform resolved again after frame boundary');
};

subtest 'missing semantic material falls back instead of dying' => sub {
    my $material_mapper = CountingMaterialMapper->new({
        DEFAULT => ZTUI::TerminalStyle::new(-fg => 0xffffff, -bg => 0x000000, -attrs => 0),
    }, {}, {});
    my $border_mapper = CountingBorderMapper->new({
        DEFAULT => ZTUI::TerminalBorderStyle::new(),
    }, {}, {});
    my ($renderer) = build_renderer(
        material_mapper => $material_mapper,
        border_mapper => $border_mapper,
    );

    lives_ok {
        $renderer->render_text(ZTUI::Matrix3::Vec::from_xy(0, 0), 'Z', -material => 'UNKNOWN');
    } 'missing material does not die';
    is_deeply(cell($renderer, 0, 0), [ord('Z'), 0xffffff, 0x000000, 0], 'fallback style is rendered');
};

done_testing;
