use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin";

use GameLoop;
use GradientHelper;
use TML qw(App Layer VBox HBox BBox Rect Text OnKey OnUpdate);

package main {
    my $gradient = GradientHelper::new(
        angle_deg => 0,
        start_color => 0x245f73,
        end_color => 0x0a2a3a,
        shift => 0.20,
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

            # $gradient->advance($delta_time);
            $needs_render = 1 if @events;

            $app->skip_render unless $needs_render;
        };

        OnKey 'q' => sub ($app, $event) {
            $app->quit;
        };

        Layer {
            # Rect {}
            #     -x => 0,
            #     -y => 0,
            #     -width => '100%',
            #     -height => '100%',
            #     -bg => sub ($app, $renderer, $node, $x, $y, $w, $h) {
            #         return $gradient->color_at_local($x, $y, $w, $h);
            #     };

            VBox {
                BBox {
                    HBox {
                        Text {} -text => "ZRogue :: Ashen Frontier", -fg => 0xe6f0f7;
                        Text {}
                            -text => sub ($app, $renderer, $node) {
                                return sprintf "FPS %5.1f", ($app->state->{fps} // 0);
                            },
                            -fg => 0x95f28f;
                        Text {} -text => "q quit", -fg => 0xf8d98b;
                    } -width => '100%', -gap => 3, -align => 'center';
                } -width => '100%',
                  -height => '12%',
                  -border => 'SINGLE',
                  -fg => 0xafc2cf,
                  -bg => 0x10222c;

                HBox {
                    VBox {
                        BBox {
                            VBox {
                                Text {} -text => "RANGER // LVL 7", -fg => 0xd7e8f2;
                                Text {} -text => "HP   42 / 55", -fg => 0xff7c7c;
                                Text {} -text => "MP   17 / 30", -fg => 0x7cc7ff;
                                Text {} -text => "STA  31 / 40", -fg => 0xb6f29a;
                                Text {} -text => "Gold 128", -fg => 0xffd166;
                            } -gap => 0;
                        } -width => '100%',
                          -height => '38%',
                          -border => 'SINGLE',
                          -fg => 0xafc2cf,
                          -bg => 0x162a34;

                        BBox {
                            VBox {
                                Text {} -text => "EQUIPMENT", -fg => 0xd7e8f2;
                                Text {} -text => "Weapon : Iron Bow", -fg => 0xcfe0ea;
                                Text {} -text => "Armor  : Leather", -fg => 0xcfe0ea;
                                Text {} -text => "Charm  : Wolf Fang", -fg => 0xcfe0ea;
                            } -gap => 0;
                        } -width => '100%',
                          -height => '30%',
                          -border => 'SINGLE',
                          -fg => 0xafc2cf,
                          -bg => 0x162a34;

                        BBox {
                            VBox {
                                Text {} -text => "INVENTORY", -fg => 0xd7e8f2;
                                Text {} -text => "- Potion x3", -fg => 0xcfe0ea;
                                Text {} -text => "- Ether  x1", -fg => 0xcfe0ea;
                                Text {} -text => "- Antidote x2", -fg => 0xcfe0ea;
                                Text {} -text => "- Key: Ruins Gate", -fg => 0xf8d98b;
                            } -gap => 0;
                        } -width => '100%',
                          -height => '32%',
                          -border => 'SINGLE',
                          -fg => 0xafc2cf,
                          -bg => 0x162a34;
                    } -width => '32%',
                      -height => '100%',
                      -gap => 0;

                    VBox {
                        BBox {
                            VBox {
                                Text {} -text => "MAP // NORTHERN RUINS", -fg => 0xd7e8f2;
                                Text {} -text => "############################", -fg => 0x6c8796;
                                Text {} -text => "#.....^^....#..............#", -fg => 0xb8c7d1;
                                Text {} -text => "#..@..^^....#...~~~........#", -fg => 0xb8c7d1;
                                Text {} -text => "#.....^^....#...~~~...T....#", -fg => 0xb8c7d1;
                                Text {} -text => "#..........##..............#", -fg => 0xb8c7d1;
                                Text {} -text => "#....C.....................#", -fg => 0xb8c7d1;
                                Text {} -text => "############################", -fg => 0x6c8796;
                                Text {} -text => "@ You   C Camp   T Target", -fg => 0xf8d98b;
                            } -gap => 0;
                        } -width => '100%',
                          -height => '66%',
                          -border => 'SINGLE',
                          -fg => 0xafc2cf,
                          -bg => 0x162a34;

                        BBox {
                            VBox {
                                Text {} -text => "QUEST", -fg => 0xd7e8f2;
                                Text {} -text => "Find the Ember Sigil in the ruins.", -fg => 0xcfe0ea;
                                Text {} -text => "Optional: Return to camp before dawn.", -fg => 0xcfe0ea;
                            } -gap => 0;
                        } -width => '100%',
                          -height => '18%',
                          -border => 'SINGLE',
                          -fg => 0xafc2cf,
                          -bg => 0x162a34;

                        BBox {
                            VBox {
                                Text {} -text => "LOG", -fg => 0xd7e8f2;
                                Text {} -text => "You hear wind through broken arches.", -fg => 0xcfe0ea;
                                Text {} -text => "Footsteps echo from the east corridor.", -fg => 0xcfe0ea;
                            } -gap => 0;
                        } -width => '100%',
                          -height => '16%',
                          -border => 'SINGLE',
                          -fg => 0xafc2cf,
                          -bg => 0x162a34;
                    } -width => '68%',
                      -height => '100%',
                      -gap => 0;
                } -width => '100%',
                  -height => '76%',
                  -gap => 0;

                BBox {
                    HBox {
                        Text {} -text => "[WASD] Move", -fg => 0xd7e8f2;
                        Text {} -text => "[E] Interact", -fg => 0xd7e8f2;
                        Text {} -text => "[I] Inventory", -fg => 0xd7e8f2;
                        Text {} -text => "[M] Map", -fg => 0xd7e8f2;
                    } -width => '100%', -gap => 3, -align => 'center';
                } -width => '100%',
                  -height => '12%',
                  -border => 'SINGLE',
                  -fg => 0xafc2cf,
                  -bg => 0x10222c;
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
    } -state => {},
      -default_fg => 0xaaaaaa,
      -default_bg => 0x0a0a0a,
      -default_attrs => 0;

    my $loop = GameLoop::new($ui->mapper, $ui);
    $loop->run();
}
