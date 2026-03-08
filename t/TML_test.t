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

    ok(!$app->update(0.1, Event::key_press('q')), 'quit key stops app');
};

done_testing;
