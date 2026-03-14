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
use TML qw(App Layer VBox HBox BBox Rect Text InputRoot FocusScope Button Toggle TextField List FieldList TextViewport ButtonRow OnKey OnUpdate);

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
        return TerminalStyle::new(-fg => 10, -bg => -1, -attrs => 1) if $material eq 'FOCUS';
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
            Rect {} -x => 1, -y => 0, -width => 4, -height => 2, -material => 'PANEL', -margin => 0;
            Text {} -x => 2, -y => -1, -text => 'A', -material => 'TEXT';
        } -x => 1, -y => 0, -margin => 0;
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
        } -gap => 1, -width => 5, -height => 5, -align => 'center', -margin => 0;
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
        } -gap => 1, -width => 6, -height => 3, -align => 'down', -margin => 0;
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
        } -width => '50%', -align => 'right', -margin => 0;
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
            } -width => '50%', -align => 'right', -margin => 0;
        } -width => 10, -height => 4, -border_material => 'ASCII', -margin => 0;
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
        } -width => '50%', -align => 'right', -margin => 0;
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
        } -width => '50%', -align => 'right', -margin => 0;
    } -state => {};

    my $renderer_before = mk_renderer(6, 20);
    $app->render($renderer_before);
    is_deeply(world_cell($renderer_before, 9, 0), [ord('X'), 5, -1, -1], 'initial width 50%');

    $app->{root}->{children}->[0]->{props}->{width} = '25%';

    my $renderer_after = mk_renderer(6, 20);
    $app->render($renderer_after);
    is_deeply(world_cell($renderer_after, 4, 0), [ord('X'), 5, -1, -1], 'updated width 25% reflected after mutation');
};

subtest 'uniform margin offsets text render origin and dimensions' => sub {
    my $app = App {
        Text {} -text => 'X', -material => 'X', -margin => 1;
    } -state => {};

    my $renderer = mk_renderer(6, 20);
    $app->render($renderer);

    is_deeply(world_cell($renderer, 1, -1), [ord('X'), 5, -1, -1], 'margin shifts text in by one cell on both axes');
    is_deeply(world_cell($renderer, 0, 0), [ord(' '), 0xffffff, 0x000000, 0], 'outer margin area is left untouched');
};

subtest 'HBox accounts for child margin in spacing' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'A', -material => 'A', -margin_x => 1;
            Text {} -text => 'B', -material => 'B';
        } -gap => 0, -margin => 0;
    } -state => {};

    my $renderer = mk_renderer();
    $app->render($renderer);

    is_deeply(world_cell($renderer, 1, 0), [ord('A'), 6, -1, -1], 'first child renders after its left margin');
    is_deeply(world_cell($renderer, 3, 0), [ord('B'), 7, -1, -1], 'second child is laid out after first child total width including margin');
};

subtest 'dynamic width coderef re-evaluates every frame' => sub {
    my $app = App {
        HBox {
            Text {} -text => 'X', -material => 'X';
        } -width => sub ($app, $renderer, $node) {
            return $app->state->{box_width};
        }, -align => 'right', -margin => 0;
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
        } -material => 'BORDER', -border_material => 'ASCII', -margin => 0;
    } -state => {};

    my $renderer = mk_renderer();
    $app->render($renderer);

    is_deeply(world_cell($renderer, 0, 0), [ord('+'), 9, -1, -1], 'top-left border uses border material style');
    is_deeply(world_cell($renderer, 1, -1), [ord('X'), 3, -1, -1], 'child is rendered one cell inside border');
};

subtest 'Text wraps within parent width by default' => sub {
    my $app = App {
        BBox {
            Text {} -text => 'ABCDEFG', -material => 'TEXT';
        } -width => 6, -height => 5, -border_material => 'ASCII', -margin => 0;
    } -state => {};

    my $renderer = mk_renderer();
    $app->render($renderer);

    is_deeply(world_cell($renderer, 1, -1), [ord('A'), 3, -1, -1], 'first wrapped line starts in content area');
    is_deeply(world_cell($renderer, 4, -1), [ord('D'), 3, -1, -1], 'first wrapped line is constrained to inner width');
    is_deeply(world_cell($renderer, 1, -2), [ord('E'), 3, -1, -1], 'second wrapped line continues on next row');
    is_deeply(world_cell($renderer, 3, -2), [ord('G'), 3, -1, -1], 'wrapped remainder is rendered on the next row');
    is_deeply(world_cell($renderer, 1, -3), [ord(' '), 0xffffff, 0x000000, 0], 'no extra wrapped row is emitted');
};

subtest 'Text can clip instead of wrap when requested' => sub {
    my $app = App {
        BBox {
            Text {} -text => 'ABCDEFG', -material => 'TEXT', -overflow => 'clip';
        } -width => 6, -height => 4, -border_material => 'ASCII', -margin => 0;
    } -state => {};

    my $renderer = mk_renderer();
    $app->render($renderer);

    is_deeply(world_cell($renderer, 1, -1), [ord('A'), 3, -1, -1], 'clipped text starts in content area');
    is_deeply(world_cell($renderer, 3, -1), [ord('C'), 3, -1, -1], 'clip keeps visible portion only');
    is_deeply(world_cell($renderer, 1, -2), [ord(' '), 0xffffff, 0x000000, 0], 'clip does not spill into next row');
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

subtest 'Button handles focus and activation before app OnKey handlers' => sub {
    my $pressed = 0;
    my $global = 0;

    my $app = App {
        InputRoot {
            Button {} -label => 'OK', -on_press => sub ($app, $node) { $pressed++ }, -focused_material => 'FOCUS', -margin => 0;
        } -margin => 0;

        OnKey ' ' => sub ($app, $event) { $global++ };
    } -state => {};

    ok($app->update(0.1, Event::key_press(' ')), 'button activation keeps app running');
    is($pressed, 1, 'focused button handled space activation');
    is($global, 0, 'handled button activation does not fall through to OnKey');

    my $renderer = mk_renderer();
    $app->render($renderer);
    is_deeply(world_cell($renderer, 0, 0), [ord('['), 10, -1, 1], 'focused button renders with focused material');
};

subtest 'adjacent buttons support local focus traversal and activation' => sub {
    my $result = 'pending';

    my $app = App {
        InputRoot {
            ButtonRow {
                Button {} -label => 'Yes', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $result = 'yes' }, -margin => 0;
                Button {} -label => 'No', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $result = 'no' }, -margin => 0;
            } -margin => 0;
        } -margin => 0;
    } -state => {};

    ok($app->update(0.1, Event::key_press('j')), 'button row consumes local forward navigation');
    ok($app->update(0.1, Event::key_press(' ')), 'focused second button activates');
    is($result, 'no', 'button-row navigation can reach and activate second button');

    my $renderer = mk_renderer(6, 20);
    $app->render($renderer);
    is_deeply(world_cell($renderer, 6, 0), [ord('['), 10, -1, 1], 'second button renders as focused after local navigation');
};

subtest 'Toggle flips bound scalar and focus traversal uses j/k' => sub {
    my $value = 0;

    my $app = App {
        InputRoot {
            ButtonRow {
                Toggle {} -label => 'Alpha', -value_ref => \$value, -margin => 0;
                Button {} -label => 'Done', -margin => 0;
            } -margin => 0;
        } -margin => 0;
    } -state => {};

    ok($app->update(0.1, Event::key_press(' ')), 'toggle activation handled');
    is($value, 1, 'toggle flips bound scalar');

    ok($app->update(0.1, Event::key_press('j')), 'focus moves forward');
    ok($app->update(0.1, Event::key_press('k')), 'focus moves backward');

    my $renderer = mk_renderer(6, 30);
    $app->render($renderer);
    is_deeply(world_cell($renderer, 0, 0), [ord('['), 0xffffff, 0x000000, 0], 'toggle renders unchecked/open bracket style at origin');
    is_deeply(world_cell($renderer, 1, 0), [ord('x'), 0xffffff, 0x000000, 0], 'toggle shows checked marker after activation');
};

subtest 'TextField requires explicit activation and supports commit/cancel' => sub {
    my $value = 'seed';
    my @changes;
    my @submits;
    my @cancels;

    my $app = App {
        InputRoot {
            TextField {}
                -value_ref => \$value,
                -width => 4,
                -on_change => sub ($app, $node, $new_value) { push @changes, $new_value },
                -on_submit => sub ($app, $node, $new_value) { push @submits, $new_value },
                -on_cancel => sub ($app, $node, $old_value) { push @cancels, $old_value },
                -focused_material => 'FOCUS',
                -active_material => 'FOCUS',
                -margin => 0;
        } -margin => 0;
    } -state => {};

    ok($app->update(0.1, Event::key_press('a')), 'app keeps running when inactive textfield ignores typing');
    is($value, 'seed', 'inactive textfield does not mutate bound scalar');

    ok($app->update(0.1, Event::key_press("\n")), 'enter activates textfield');
    ok($app->update(0.1, Event::key_press('a')), 'active textfield accepts printable input');
    ok($app->update(0.1, Event::key_press('b')), 'active textfield accepts subsequent printable input');
    ok($app->update(0.1, Event::key_press("\x7f")), 'textfield accepts backspace');
    ok($app->update(0.1, Event::key_press("\n")), 'enter commits active textfield');

    is($value, 'seeda', 'textfield commit writes draft buffer into bound scalar');
    is_deeply(\@changes, ['seeda'], 'textfield emits change callback only on commit');
    is_deeply(\@submits, ['seeda'], 'textfield emits submit callback on commit');
    is_deeply(\@cancels, [], 'textfield has not cancelled yet');

    ok($app->update(0.1, Event::key_press("\n")), 'enter re-activates textfield');
    ok($app->update(0.1, Event::key_press('z')), 'active textfield appends new draft content');
    ok($app->update(0.1, Event::key_press("\e")), 'esc cancels active textfield');

    is($value, 'seeda', 'cancel drops draft and preserves committed value');
    is_deeply(\@cancels, ['seeda'], 'textfield emits cancel callback with preserved bound value');

    my $renderer = mk_renderer(6, 20);
    $app->render($renderer);
    is_deeply(world_cell($renderer, 0, 0), [ord('['), 10, -1, 1], 'focused textfield uses focused material');
    is_deeply(world_cell($renderer, 1, 0), [ord('s'), 10, -1, 1], 'inactive textfield renders committed value');
    is_deeply(world_cell($renderer, 4, 0), [ord('d'), 10, -1, 1], 'inactive textfield does not render an active cursor');
};

subtest 'List keeps j/k in local domain and J exits to sibling branch' => sub {
    my @items = ('One', 'Two', 'Three');
    my $selected = 0;
    my @activated;

    my $app = App {
        InputRoot {
            FocusScope {
                HBox {
                    List {}
                        -items_ref => \@items,
                        -selected_index_ref => \$selected,
                        -height => 2,
                        -width => 8,
                        -focused_material => 'FOCUS',
                        -on_activate => sub ($app, $node, $idx, $item) {
                            push @activated, [$idx, $item->{label}];
                        },
                        -margin => 0;
                    Button {} -label => 'OK', -margin => 0;
                } -gap => 1, -margin => 0;
            } -margin => 0;
        } -margin => 0;
    } -state => {};

    ok($app->update(0.1, Event::key_press('j')), 'list consumes local down navigation');
    is($selected, 1, 'list selection moves inside list');

    ok($app->update(0.1, Event::key_press(' ')), 'list activation handled');
    is_deeply(\@activated, [[1, 'Two']], 'list activation reports selected item');

    ok($app->update(0.1, Event::key_press('J')), 'exit navigation moves to sibling branch');
    ok($app->update(0.1, Event::key_press(' ')), 'button activation handled after focus move');

    my $renderer = mk_renderer(8, 30);
    $app->render($renderer);
    is_deeply(world_cell($renderer, 0, 0), [ord(' '), 0xffffff, 0x000000, 0], 'first visible row is unselected after moving down once');
    is_deeply(world_cell($renderer, 0, -1), [ord('>'), 0xffffff, 0x000000, 0], 'selected list row remains marked after focus moves away');
};

subtest 'TextViewport scrolls locally without leaving focus domain' => sub {
    my $scroll = 0;
    my @lines = ('alpha', 'bravo', 'charlie', 'delta');

    my $app = App {
        InputRoot {
            TextViewport {}
                -lines_ref => \@lines,
                -scroll_ref => \$scroll,
                -width => 7,
                -height => 2,
                -focused_material => 'FOCUS',
                -margin => 0;
        } -margin => 0;
    } -state => {};

    ok($app->update(0.1, Event::key_press('j')), 'viewport consumes local down scroll');
    is($scroll, 1, 'viewport scroll offset advances');

    my $renderer = mk_renderer(8, 20);
    $app->render($renderer);
    is_deeply(world_cell($renderer, 0, 0), [ord('b'), 10, -1, 1], 'viewport renders from scrolled line');
    is_deeply(world_cell($renderer, 0, -1), [ord('c'), 10, -1, 1], 'viewport renders following visible line');
};

subtest 'FieldList supports local field navigation and editing' => sub {
    my $name = 'Ada';
    my $debug = 1;
    my $selected = 0;
    my @fields = (
        { label => 'Name', type => 'text', value_ref => \$name, width => 5 },
        { label => 'Debug', type => 'toggle', value_ref => \$debug },
    );

    my $app = App {
        InputRoot {
            FieldList {}
                -fields => \@fields,
                -selected_index_ref => \$selected,
                -material => 'TEXT',
                -focused_material => 'FOCUS',
                -active_material => 'FOCUS',
                -margin => 0;
        } -margin => 0;
    } -state => {};

    ok($app->update(0.1, Event::key_press("\n")), 'enter activates selected text field');
    ok($app->update(0.1, Event::key_press('x')), 'active field accepts draft edits');
    ok($app->update(0.1, Event::key_press("\n")), 'enter commits text field draft');
    is($name, 'Adax', 'field list commits edited text value');

    ok($app->update(0.1, Event::key_press('j')), 'j moves to next field');
    is($selected, 1, 'field list updates selected field index');
    ok($app->update(0.1, Event::key_press(' ')), 'space toggles selected toggle field');
    is($debug, 0, 'field list toggles selected toggle value');

    my $renderer = mk_renderer(8, 40);
    $app->render($renderer);

    is_deeply(world_cell($renderer, 0, 0), [ord(' '), 3, -1, -1], 'unselected first row uses plain prefix after moving away');
    is_deeply(world_cell($renderer, 0, -1), [ord('>'), 10, -1, 1], 'selected second row renders focus marker');
    is_deeply(world_cell($renderer, 11, -1), [ord(' '), 10, -1, 1], 'toggle preview reflects updated off state');
};

subtest 'exit navigation moves from list container to button row sibling' => sub {
    my @items = ('One', 'Two');
    my $selected = 0;
    my $result = 'pending';

    my $app = App {
        InputRoot {
            FocusScope {
                VBox {
                    List {}
                        -items_ref => \@items,
                        -selected_index_ref => \$selected,
                        -height => 2,
                        -width => 8,
                        -focused_material => 'FOCUS',
                        -margin => 0;
                    ButtonRow {
                        Button {} -label => 'OK', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $result = 'ok' }, -margin => 0;
                        Button {} -label => 'Cancel', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $result = 'cancel' }, -margin => 0;
                    } -margin => 0;
                } -gap => 1, -margin => 0;
            } -margin => 0;
        } -margin => 0;
    } -state => {};

    ok($app->update(0.1, Event::key_press('J')), 'uppercase exit leaves list domain');
    ok($app->update(0.1, Event::key_press(' ')), 'button row receives focus after exit');
    is($result, 'ok', 'exit navigation lands on first button-row descendant');
};

subtest 'mixed dialog exit navigation moves between pane containers' => sub {
    my $name = 'Ada';
    my @items = ('One', 'Two');
    my $selected = 0;
    my $scroll = 0;
    my @lines = ('alpha', 'bravo', 'charlie');

    my $app = App {
        InputRoot {
            FocusScope {
                HBox {
                    VBox {
                        TextField {} -value_ref => \$name, -width => 5, -focused_material => 'FOCUS', -margin => 0;
                        List {}
                            -items_ref => \@items,
                            -selected_index_ref => \$selected,
                            -height => 2,
                            -width => 8,
                            -focused_material => 'FOCUS',
                            -margin => 0;
                    } -gap => 1, -margin => 0;
                    VBox {
                        TextViewport {}
                            -lines_ref => \@lines,
                            -scroll_ref => \$scroll,
                            -width => 7,
                            -height => 2,
                            -focused_material => 'FOCUS',
                            -margin => 0;
                        Button {} -label => 'OK', -focused_material => 'FOCUS', -margin => 0;
                    } -gap => 1, -margin => 0;
                } -gap => 2, -margin => 0;
            } -margin => 0;
        } -margin => 0;
    } -state => {};

    ok($app->update(0.1, Event::key_press('j')), 'local navigation stays inside left pane');
    ok($app->update(0.1, Event::key_press('J')), 'exit navigation jumps to right pane');

    my $renderer = mk_renderer(10, 40);
    $app->render($renderer);
    is_deeply(world_cell($renderer, 10, 0), [ord('a'), 10, -1, 1], 'right pane viewport becomes focused after pane exit');
};

subtest 'custom InputRoot keymap overrides default navigation bindings' => sub {
    my $result = 'pending';

    my $app = App {
        InputRoot {
            ButtonRow {
                Button {} -label => 'Yes', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $result = 'yes' }, -margin => 0;
                Button {} -label => 'No', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $result = 'no' }, -margin => 0;
            } -margin => 0;
        } -margin => 0,
          -keymap => {
              next => ['l'],
              prev => ['h'],
              exit_next => ['L'],
              exit_prev => ['H'],
          };
    } -state => {};

    ok($app->update(0.1, Event::key_press('l')), 'root keymap override moves focus forward');
    ok($app->update(0.1, Event::key_press(' ')), 'overridden navigation still preserves activation dispatch');
    is($result, 'no', 'custom keymap replaced default local navigation');
    ok($app->update(0.1, Event::key_press('j')), 'unbound default key falls through without quitting');
};

done_testing;
