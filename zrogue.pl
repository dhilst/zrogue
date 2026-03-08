use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin";

use GameLoop;
use GradientHelper;
use TML qw(App Layer HBox BBox Rect Text OnKey OnUpdate);

package main {
    my $gradient = GradientHelper::new(
        angle_deg => 0,
        start_color => 0x245f73,
        end_color => 0x0a2a3a,
        shift => 0.20,
    );

    my $ui = App {
        OnUpdate {
            my ($app, $delta_time) = @_;
            if ($delta_time > 0) {
                $app->state->{fps} = 1 / $delta_time;
            }
            $gradient->advance($delta_time);
        };

        OnKey 'q' => sub ($app, $event) {
            $app->quit;
        };

        Layer {
            Rect {}
                -x => -12,
                -y => 5,
                -width => 24,
                -height => 10,
                -bg => sub ($app, $renderer, $node, $x, $y, $w, $h) {
                    return $gradient->color_at_local($x, $y, $w, $h);
                };
            Text {} -x => 1, -y => -4, -text => "Press q to quit", -fg => 0xc7f3ff, -bg => 0x0a2a3a;

            BBox {
                HBox {
                    Text {} -text => "HP:42", -fg => 0xffd166;
                    Text {} -text => "MP:17", -fg => 0x73d2de;
                    Text {} -text => "LVL:7", -fg => 0x95f28f;
                } -gap => 2;
            } -x => -10, -y => 1,
              -border => 'SINGLE',
              -fg => 0xc7f3ff,
              -bg => 0x0a2a3a;
        };

        Text {} 
            -x => sub ($app, $renderer, $node) { int(($renderer->width - 1) / 2) },
            -y => sub ($app, $renderer, $node) { int($renderer->height / 2) },
            -text => sub ($app, $renderer, $node) { sprintf "FPS %6.1f", ($app->state->{fps} // 0) },
            -justify => 'right',
            -fg => 0x8cf29a,
            -bg => 0x0a0a0a;
    } -state => {},
      -default_fg => 0xaaaaaa,
      -default_bg => 0x0a0a0a,
      -default_attrs => 0;

    my $loop = GameLoop::new($ui->mapper, $ui);
    $loop->run();
}
