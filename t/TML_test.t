use v5.36;
use Test::More;

use lib '.';
use BorderMapper;
use Event;
use MaterialMapper;
use Surface;
use TML qw(App Layer VBox HBox BBox Rect Text OnKey OnUpdate);

sub mk_surface($h = 8, $w = 20) {
    my $mat = MaterialMapper::from_callback(sub ($material) {
        return {};
    });
    return Surface::new($h, $w, -material => $mat);
}

subtest 'rect and nested text render at expected positions' => sub {
    my $app = App {
        Layer {
            Rect {} -x => 1, -y => 0, -width => 4, -height => 2, -bg => 9;
            Text {} -x => 2, -y => -1, -text => 'A', -fg => 3;
        } -x => 1, -y => 0;
    } -state => {};

    my $surface = mk_surface();
    $app->render($surface);

    is_deeply(
        [$surface->buffer->get(3, 1)],
        [ord('A'), 3, 9, -1],
        'text overlays rect with inherited offset'
    );
};

subtest 'dynamic text binding reads app state' => sub {
    my $app = App {
        Text {} -x => 0, -y => 0,
            -text => sub ($app, $renderer, $node) {
                return sprintf "FPS %.1f", $app->state->{fps};
            },
            -fg => 7;
    } -state => { fps => 42.5 };

    my $surface = mk_surface();
    $app->render($surface);

    is_deeply(
        [$surface->buffer->get(0, 0)],
        [ord('F'), 7, -1, -1],
        'dynamic text rendered'
    );
};

subtest 'rect supports per-cell bg callback' => sub {
    my $app = App {
        Rect {}
            -x => 0, -y => 0, -width => 2, -height => 2,
            -bg => sub ($app, $renderer, $node, $x, $y, $w, $h) {
                return $x + ($y * 10);
            };
    } -state => {};

    my $surface = mk_surface();
    $app->render($surface);

    is_deeply([$surface->buffer->get(0, 0)], [ord(' '), -1, 0, -1], 'cell 0,0');
    is_deeply([$surface->buffer->get(1, 0)], [ord(' '), -1, 1, -1], 'cell 1,0');
    is_deeply([$surface->buffer->get(0, 1)], [ord(' '), -1, 10, -1], 'cell 0,1');
};

subtest 'VBox applies gap and center alignment' => sub {
    my $app = App {
        VBox {
            Text {} -text => 'A', -fg => 1;
            Text {} -text => 'B', -fg => 2;
        } -gap => 1, -width => 5, -height => 5, -align => 'center';
    } -state => {};

    my $surface = mk_surface();
    $app->render($surface);

    is_deeply([$surface->buffer->get(2, 1)], [ord('A'), 1, -1, -1], 'A at centered row');
    is_deeply([$surface->buffer->get(2, 3)], [ord('B'), 2, -1, -1], 'B at centered row+gap');
};

subtest 'HBox applies gap and down alignment' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'L', -fg => 3;
            Text {} -text => 'R', -fg => 4;
        } -gap => 1, -width => 6, -height => 3, -align => 'down';
    } -state => {};

    my $surface = mk_surface();
    $app->render($surface);

    is_deeply([$surface->buffer->get(3, 2)], [ord('L'), 3, -1, -1], 'left text shifted by right/down alignment');
    is_deeply([$surface->buffer->get(5, 2)], [ord('R'), 4, -1, -1], 'right text shifted by gap');
};

subtest 'HBox width supports percentage at root' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'X', -fg => 5;
        } -width => '50%', -align => 'right';
    } -state => {};

    my $surface = mk_surface(6, 20);
    $app->render($surface);

    is_deeply(
        [$surface->buffer->get(9, 0)],
        [ord('X'), 5, -1, -1],
        '50% root width (20 => 10) right aligns X at col 9'
    );
};

subtest 'HBox width percentage resolves against BBox inner width' => sub {
    my $app = App {
        BBox {
            HBox {
                Text {} -text => 'A', -fg => 6;
                Text {} -text => 'B', -fg => 7;
            } -width => '50%', -align => 'right';
        } -width => 10, -height => 4, -border => 'ASCII';
    } -state => {};

    my $surface = mk_surface();
    $app->render($surface);

    # BBox width 10 => inner width 8; HBox width 50% => 4; AB right aligned => cols 3,4 in inner box
    is_deeply([$surface->buffer->get(3, 1)], [ord('A'), 6, -1, -1], 'A positioned from percent width');
    is_deeply([$surface->buffer->get(4, 1)], [ord('B'), 7, -1, -1], 'B positioned from percent width');
};

subtest 'HBox layout cache respects renderer size changes across renders' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'X', -fg => 5;
        } -width => '50%', -align => 'right';
    } -state => {};

    my $surface_20 = mk_surface(6, 20);
    $app->render($surface_20);
    is_deeply([$surface_20->buffer->get(9, 0)], [ord('X'), 5, -1, -1], '20 cols => X at 9');

    my $surface_40 = mk_surface(6, 40);
    $app->render($surface_40);
    is_deeply([$surface_40->buffer->get(19, 0)], [ord('X'), 5, -1, -1], '40 cols => X at 19');
};

subtest 'HBox layout cache invalidates when tree props change' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'X', -fg => 5;
        } -width => '50%', -align => 'right';
    } -state => {};

    my $surface_before = mk_surface(6, 20);
    $app->render($surface_before);
    is_deeply([$surface_before->buffer->get(9, 0)], [ord('X'), 5, -1, -1], 'initial width 50%');

    $app->{root}->{children}->[0]->{props}->{width} = '25%';

    my $surface_after = mk_surface(6, 20);
    $app->render($surface_after);
    is_deeply([$surface_after->buffer->get(4, 0)], [ord('X'), 5, -1, -1], 'updated width 25% reflected after mutation');
};

subtest 'dynamic width coderef re-evaluates every frame' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'X', -fg => 5;
        } -width => sub ($app, $renderer, $node) {
            return $app->state->{box_width};
        }, -align => 'right';
    } -state => { box_width => 10 };

    my $surface_before = mk_surface(6, 20);
    $app->render($surface_before);
    is_deeply([$surface_before->buffer->get(9, 0)], [ord('X'), 5, -1, -1], 'initial dynamic width used');

    $app->state->{box_width} = 4;

    my $surface_after = mk_surface(6, 20);
    $app->render($surface_after);
    is_deeply([$surface_after->buffer->get(3, 0)], [ord('X'), 5, -1, -1], 'updated dynamic width reflected on next render');
};

subtest 'BBox uses BorderMapper and material mapping for style' => sub {
    my $mat = MaterialMapper::from_callback(sub ($material) {
        return { -fg => 9 } if $material eq 'BORDER';
        return { -fg => -1, -bg => -1, -attrs => -1 } if $material eq 'DEFAULT';
    });
    my $bmap = BorderMapper::from_callback(sub ($material) {
        return "+-+\n|.|\n+-+" if $material eq 'ASCII';
    });

    my $app = App {
        BBox {
            Text {} -text => 'X', -fg => 2;
        } -material => 'BORDER', -border => 'ASCII';
    } -state => {},
      -material_mapper => $mat,
      -border_mapper => $bmap;

    my $surface = mk_surface();
    $app->render($surface);

    is_deeply([$surface->buffer->get(0, 0)], [ord('+'), 9, -1, -1], 'top-left border uses border glyph and material style');
    is_deeply([$surface->buffer->get(1, 1)], [ord('X'), 2, -1, -1], 'child is rendered one cell inside border');
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
