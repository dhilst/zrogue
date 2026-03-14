use v5.36;
use Test::More;

use lib '.';
use Event;
use GameLoop;
use Matrix3 qw($ID);
use Renderers;
use TerminalBorderStyle;
use TerminalStyle;
use Theme;
use TML qw(App Layer VBox HBox BBox Rect Text OnKey OnUpdate);

{
    package TMLTest::MaterialMapper;
    use v5.36;
    sub new($class, @ignored) {
        bless { calls => {} }, $class;
    }
    sub lookup($self, $material) {
        $self->{calls}{$material}++;
        return TerminalStyle::new(-fg => 1, -bg => 2, -attrs => 3) if $material eq 'PANEL';
        return TerminalStyle::new(-fg => 3, -bg => -1, -attrs => -1) if $material eq 'TEXT';
        return TerminalStyle::new(-fg => 6, -bg => -1, -attrs => -1) if $material eq 'A';
        return TerminalStyle::new(-fg => 7, -bg => -1, -attrs => -1) if $material eq 'B';
        return TerminalStyle::new(-fg => 5, -bg => -1, -attrs => -1) if $material eq 'X';
        return TerminalStyle::new(-fg => 9, -bg => 0, -attrs => -1) if $material eq 'BORDER';
        return TerminalStyle::new(-fg => 0xffffff, -bg => 0x000000, -attrs => 0) if $material eq 'DEFAULT';
        return undef;
    }
    sub style($self, $material) { $self->lookup($material) }
    sub cache_class($self, $material) { 'STATIC_UNIFORM' }
    sub cache_key($self, $dt, $x, $y, $material) { $material }
}

{
    package TMLTest::BorderMapper;
    use v5.36;
    sub new($class, @ignored) {
        bless {}, $class;
    }
    sub lookup($self, $material) {
        return TerminalBorderStyle::new(
            -fg => 9,
            -bg => -1,
            -attrs => -1,
            -border => ['+', '-', '+', '|', ' ', '|', '+', '-', '+'],
        ) if $material eq 'ASCII' || $material eq 'BORDER';
        return TerminalBorderStyle::new() if $material eq 'DEFAULT';
        return undef;
    }
    sub style($self, $material) { $self->lookup($material) }
    sub cache_class($self, $material) { 'STATIC_UNIFORM' }
    sub cache_key($self, $dt, $x, $y, $material, $edge) { join ':', $material, $edge }
}

sub mk_renderer($h = 8, $w = 20) {
    my $theme = Theme::new(
        -material_mapper => TMLTest::MaterialMapper->new(),
        -border_mapper => TMLTest::BorderMapper->new(),
    );
    return Renderers::DoubleBuffering::new(GameLoop::terminal_space($w, $h), $h, $w, $theme, ' ');
}

sub world_cell($renderer, $x, $y) {
    my $pos = Matrix3::Vec::from_xy($x, $y) * $renderer->terminal_space;
    my ($col, $row) = (int($pos->[0]), int($pos->[1]));
    return [ $renderer->bbuf->get($col, $row) ];
}

subtest 'rect and nested text render at expected positions' => sub {
    my $app = App {
        Layer {
            Rect {} -x => 1, -y => 0, -width => 4, -height => 2, -material => 'PANEL';
            Text {} -x => 2, -y => -1, -text => 'A', -material => 'TEXT';
        } -x => 1, -y => 0;
    } -state => {};

    my $renderer = mk_renderer();
    $app->render($renderer);

    is_deeply(
        world_cell($renderer, 3, -1),
        [ord('A'), 3, -1, -1],
        'text overlays rect with inherited offset'
    );
};

subtest 'dynamic text binding reads app state' => sub {
    my $app = App {
        Text {} -x => 0, -y => 0,
            -text => sub ($app, $renderer, $node) {
                return sprintf "FPS %.1f", $app->state->{fps};
            },
            -material => 'TEXT';
    } -state => { fps => 42.5 };

    my $renderer = mk_renderer();
    $app->render($renderer);

    is_deeply(
        world_cell($renderer, 0, 0),
        [ord('F'), 3, -1, -1],
        'dynamic text rendered'
    );
};

subtest 'VBox applies gap and center alignment' => sub {
    my $app = App {
        VBox {
            Text {} -text => 'A', -material => 'A';
            Text {} -text => 'B', -material => 'B';
        } -gap => 1, -width => 5, -height => 5, -align => 'center';
    } -state => {};

    my $renderer = mk_renderer();
    $app->render($renderer);

    is_deeply(world_cell($renderer, 2, -1), [ord('A'), 6, -1, -1], 'A at centered row');
    is_deeply(world_cell($renderer, 2, -3), [ord('B'), 7, -1, -1], 'B at centered row+gap');
};

subtest 'HBox applies gap and down alignment' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'L', -material => 'TEXT';
            Text {} -text => 'R', -material => 'TEXT';
        } -gap => 1, -width => 6, -height => 3, -align => 'down';
    } -state => {};

    my $renderer = mk_renderer();
    $app->render($renderer);

    is_deeply(world_cell($renderer, 3, -2), [ord('L'), 3, -1, -1], 'left text shifted by right/down alignment');
    is_deeply(world_cell($renderer, 5, -2), [ord('R'), 3, -1, -1], 'right text shifted by gap');
};

subtest 'HBox width supports percentage at root' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'X', -material => 'X';
        } -width => '50%', -align => 'right';
    } -state => {};

    my $renderer = mk_renderer(6, 20);
    $app->render($renderer);

    is_deeply(
        world_cell($renderer, 9, 0),
        [ord('X'), 5, -1, -1],
        '50% root width (20 => 10) right aligns X at col 9'
    );
};

subtest 'HBox width percentage resolves against BBox inner width' => sub {
    my $app = App {
        BBox {
            HBox {
                Text {} -text => 'A', -material => 'A';
                Text {} -text => 'B', -material => 'B';
            } -width => '50%', -align => 'right';
        } -width => 10, -height => 4, -border_material => 'ASCII';
    } -state => {};

    my $renderer = mk_renderer();
    $app->render($renderer);

    # BBox width 10 => inner width 8; HBox width 50% => 4; AB right aligned => cols 3,4 in inner box
    is_deeply(world_cell($renderer, 3, -1), [ord('A'), 6, -1, -1], 'A positioned from percent width');
    is_deeply(world_cell($renderer, 4, -1), [ord('B'), 7, -1, -1], 'B positioned from percent width');
};

subtest 'HBox layout cache respects renderer size changes across renders' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'X', -material => 'X';
        } -width => '50%', -align => 'right';
    } -state => {};

    my $renderer_20 = mk_renderer(6, 20);
    $app->render($renderer_20);
    is_deeply(world_cell($renderer_20, 9, 0), [ord('X'), 5, -1, -1], '20 cols => X at 9');

    my $renderer_40 = mk_renderer(6, 40);
    $app->render($renderer_40);
    is_deeply(world_cell($renderer_40, 19, 0), [ord('X'), 5, -1, -1], '40 cols => X at 19');
};

subtest 'HBox layout cache invalidates when tree props change' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'X', -material => 'X';
        } -width => '50%', -align => 'right';
    } -state => {};

    my $renderer_before = mk_renderer(6, 20);
    $app->render($renderer_before);
    is_deeply(world_cell($renderer_before, 9, 0), [ord('X'), 5, -1, -1], 'initial width 50%');

    $app->{root}->{children}->[0]->{props}->{width} = '25%';

    my $renderer_after = mk_renderer(6, 20);
    $app->render($renderer_after);
    is_deeply(world_cell($renderer_after, 4, 0), [ord('X'), 5, -1, -1], 'updated width 25% reflected after mutation');
};

subtest 'dynamic width coderef re-evaluates every frame' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'X', -material => 'X';
        } -width => sub ($app, $renderer, $node) {
            return $app->state->{box_width};
        }, -align => 'right';
    } -state => { box_width => 10 };

    my $renderer_before = mk_renderer(6, 20);
    $app->render($renderer_before);
    is_deeply(world_cell($renderer_before, 9, 0), [ord('X'), 5, -1, -1], 'initial dynamic width used');

    $app->state->{box_width} = 4;

    my $renderer_after = mk_renderer(6, 20);
    $app->render($renderer_after);
    is_deeply(world_cell($renderer_after, 3, 0), [ord('X'), 5, -1, -1], 'updated dynamic width reflected on next render');
};

subtest 'BBox uses border_material and material semantics' => sub {
    my $app = App {
        BBox {
            Text {} -text => 'X', -material => 'TEXT';
        } -material => 'BORDER', -border_material => 'ASCII';
    } -state => {};

    my $renderer = mk_renderer();
    $app->render($renderer);

    is_deeply(world_cell($renderer, 0, 0), [ord('+'), 9, -1, -1], 'top-left border uses border material style');
    is_deeply(world_cell($renderer, 1, -1), [ord('X'), 3, -1, -1], 'child is rendered one cell inside border');
};

subtest 'update and key handlers can mutate state and quit app' => sub {
    my $updates = 0;
    my $app = App {
        OnUpdate {
            my ($app, $dt, @events) = @_;
            $updates++;
            $app->state->{fps} = 1 / $dt if $dt > 0;
        };
        OnKey 'q' => sub ($app, $event) { $app->quit; };
    } -state => {};

    ok($app->update(0.5), 'app keeps running without quit key');
    is($updates, 1, 'update callback was invoked');
    is(sprintf('%.1f', $app->state->{fps}), '2.0', 'update callback changed state');

    $app->skip_render;
    is($app->update(0.2), -1, 'skip_render causes next update to return -1');
    ok($app->update(0.2), 'skip_render only applies to one frame');

    ok(!$app->update(0.1, Event::key_press('q')), 'quit key stops app');
};

done_testing;
