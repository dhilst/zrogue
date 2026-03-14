use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin";

use BorderMapper;
use GameLoop;
use MaterialMapper;
use TerminalBorderStyle;
use TerminalStyle;
use Theme;
use TML qw(App Layer VBox HBox BBox Rect Text OnKey OnUpdate);

package main {
    my $material_mapper = MaterialMapper::from_callback(sub ($material) {
        state %styles = (
            DEFAULT => TerminalStyle::new(-fg => 0xaaaaaa, -bg => 0x0a0a0a, -attrs => 0),
            TITLE => TerminalStyle::new(-fg => 0xe6f0f7),
            FPS => TerminalStyle::new(-fg => 0x95f28f),
            HOTKEY => TerminalStyle::new(-fg => 0xf8d98b),
            PANEL_TEXT => TerminalStyle::new(-fg => 0xd7e8f2),
            PANEL_TEXT_DIM => TerminalStyle::new(-fg => 0xcfe0ea),
            PANEL_TEXT_WARN => TerminalStyle::new(-fg => 0xff7c7c),
            PANEL_TEXT_MANA => TerminalStyle::new(-fg => 0x7cc7ff),
            PANEL_TEXT_STAMINA => TerminalStyle::new(-fg => 0xb6f29a),
            PANEL_TEXT_GOLD => TerminalStyle::new(-fg => 0xffd166),
            PANEL_TEXT_MAP => TerminalStyle::new(-fg => 0xb8c7d1),
            PANEL_TEXT_MAP_DIM => TerminalStyle::new(-fg => 0x6c8796),
            FRAME => TerminalStyle::new(-fg => 0xafc2cf, -bg => 0x162a34),
            FRAME_BAR => TerminalStyle::new(-fg => 0xafc2cf, -bg => 0x10222c),
            BG => TerminalStyle::new(-fg => -1, -bg => 0x10222c),
        );
        return $styles{$material} // $styles{DEFAULT};
    });

    my $border_mapper = BorderMapper::from_callback(sub ($material) {
        state %styles = (
            DEFAULT => TerminalBorderStyle::new(),
            FRAME => TerminalBorderStyle::new(
                -fg => 0xafc2cf,
                -bg => 0x162a34,
                -attrs => 0,
                -border => ['┌', '─', '┐', '│', ' ', '│', '└', '─', '┘'],
            ),
            FRAME_BAR => TerminalBorderStyle::new(
                -fg => 0xafc2cf,
                -bg => 0x10222c,
                -attrs => 0,
                -border => ['┌', '─', '┐', '│', ' ', '│', '└', '─', '┘'],
            ),
        );
        return $styles{$material} // $styles{DEFAULT};
    });

    my $theme = Theme::new(
        -material_mapper => $material_mapper,
        -border_mapper => $border_mapper,
    );

    my $ui = App {
        OnUpdate {
            my ($app, $delta_time, @events) = @_;
            my $state = $app->state;

            my $needs_render = !$state->{_ui_bootstrapped};
            $state->{_ui_bootstrapped} = 1;

            $state->{_fps_sample_accum} = ($state->{_fps_sample_accum} // 0) + $delta_time;
            if ($state->{_fps_sample_accum} >= 0.25) {
                $state->{fps} = 1 / $delta_time if $delta_time > 0;
                $state->{_fps_sample_accum} = 0;
                $needs_render = 1;
            }

            $needs_render = 1 if @events;

            $app->skip_render unless $needs_render;
        };

        OnKey 'q' => sub ($app, $event) {
            $app->quit;
        };

        Layer {
            Rect {}
                -x => 0,
                -y => 0,
                -width => '100%',
                -height => '100%',
                -material => 'BG';

            VBox {
                BBox {
                    HBox {
                        Text {} -text => "ZRogue :: Ashen Frontier", -material => 'TITLE';
                        Text {}
                            -text => sub ($app, $renderer, $node) {
                                return sprintf "FPS %5.1f", ($app->state->{fps} // 0);
                            },
                            -material => 'FPS';
                        Text {} -text => "q quit", -material => 'HOTKEY';
                    } -width => '100%', -gap => 3, -align => 'center';
                } -width => '100%',
                  -height => '12%',
                  -border_material => 'FRAME_BAR',
                  -material => 'FRAME_BAR';

                HBox {
                    VBox {
                        BBox {
                            VBox {
                                Text {} -text => "RANGER // LVL 7", -material => 'PANEL_TEXT';
                                Text {} -text => "HP   42 / 55", -material => 'PANEL_TEXT_WARN';
                                Text {} -text => "MP   17 / 30", -material => 'PANEL_TEXT_MANA';
                                Text {} -text => "STA  31 / 40", -material => 'PANEL_TEXT_STAMINA';
                                Text {} -text => "Gold 128", -material => 'PANEL_TEXT_GOLD';
                            } -gap => 0;
                        } -width => '100%',
                          -height => '38%',
                          -border_material => 'FRAME',
                          -material => 'FRAME';

                        BBox {
                            VBox {
                                Text {} -text => "EQUIPMENT", -material => 'PANEL_TEXT';
                                Text {} -text => "Weapon : Iron Bow", -material => 'PANEL_TEXT_DIM';
                                Text {} -text => "Armor  : Leather", -material => 'PANEL_TEXT_DIM';
                                Text {} -text => "Charm  : Wolf Fang", -material => 'PANEL_TEXT_DIM';
                            } -gap => 0;
                        } -width => '100%',
                          -height => '30%',
                          -border_material => 'FRAME',
                          -material => 'FRAME';

                        BBox {
                            VBox {
                                Text {} -text => "INVENTORY", -material => 'PANEL_TEXT';
                                Text {} -text => "- Potion x3", -material => 'PANEL_TEXT_DIM';
                                Text {} -text => "- Ether  x1", -material => 'PANEL_TEXT_DIM';
                                Text {} -text => "- Antidote x2", -material => 'PANEL_TEXT_DIM';
                                Text {} -text => "- Key: Ruins Gate", -material => 'HOTKEY';
                            } -gap => 0;
                        } -width => '100%',
                          -height => '32%',
                          -border_material => 'FRAME',
                          -material => 'FRAME';
                    } -width => '32%',
                      -height => '100%',
                      -gap => 0;

                    VBox {
                        BBox {
                            VBox {
                                Text {} -text => "MAP // NORTHERN RUINS", -material => 'PANEL_TEXT';
                                Text {} -text => "############################", -material => 'PANEL_TEXT_MAP_DIM';
                                Text {} -text => "#.....^^....#..............#", -material => 'PANEL_TEXT_MAP';
                                Text {} -text => "#..@..^^....#...~~~........#", -material => 'PANEL_TEXT_MAP';
                                Text {} -text => "#.....^^....#...~~~...T....#", -material => 'PANEL_TEXT_MAP';
                                Text {} -text => "#..........##..............#", -material => 'PANEL_TEXT_MAP';
                                Text {} -text => "#....C.....................#", -material => 'PANEL_TEXT_MAP';
                                Text {} -text => "############################", -material => 'PANEL_TEXT_MAP_DIM';
                                Text {} -text => "@ You   C Camp   T Target", -material => 'HOTKEY';
                            } -gap => 0;
                        } -width => '100%',
                          -height => '66%',
                          -border_material => 'FRAME',
                          -material => 'FRAME';

                        BBox {
                            VBox {
                                Text {} -text => "QUEST", -material => 'PANEL_TEXT';
                                Text {} -text => "Find the Ember Sigil in the ruins.", -material => 'PANEL_TEXT_DIM';
                                Text {} -text => "Optional: Return to camp before dawn.", -material => 'PANEL_TEXT_DIM';
                            } -gap => 0;
                        } -width => '100%',
                          -height => '18%',
                          -border_material => 'FRAME',
                          -material => 'FRAME';

                        BBox {
                            VBox {
                                Text {} -text => "LOG", -material => 'PANEL_TEXT';
                                Text {} -text => "You hear wind through broken arches.", -material => 'PANEL_TEXT_DIM';
                                Text {} -text => "Footsteps echo from the east corridor.", -material => 'PANEL_TEXT_DIM';
                            } -gap => 0;
                        } -width => '100%',
                          -height => '16%',
                          -border_material => 'FRAME',
                          -material => 'FRAME';
                    } -width => '68%',
                      -height => '100%',
                      -gap => 0;
                } -width => '100%',
                  -height => '76%',
                  -gap => 0;

                BBox {
                    HBox {
                        Text {} -text => "[WASD] Move", -material => 'PANEL_TEXT';
                        Text {} -text => "[E] Interact", -material => 'PANEL_TEXT';
                        Text {} -text => "[I] Inventory", -material => 'PANEL_TEXT';
                        Text {} -text => "[M] Map", -material => 'PANEL_TEXT';
                    } -width => '100%', -gap => 3, -align => 'center';
                } -width => '100%',
                  -height => '12%',
                  -border_material => 'FRAME_BAR',
                  -material => 'FRAME_BAR';
            } -x => 0,
              -y => 0,
              -width => '100%',
              -height => '100%',
              -gap => 0;
        } -x => sub ($app, $renderer, $node) {
                return -int($renderer->width / 2) + 1;
            },
          -y => sub ($app, $renderer, $node) {
                return int($renderer->height / 2) - 1;
            };
    } -state => {};

    my $loop = GameLoop::new($theme, $ui);
    $loop->run();
}
