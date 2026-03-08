use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin";

use Event;
use GameLoop;
use GradientHelper;
use MaterialMapper;
use Matrix3;
use Quad;

package ZRogue::Widget {
    use v5.36;

    sub new() {
        my $quad = Quad::from_wh(24, 10, 'QUAD');
        my $self = bless {
            gradient => GradientHelper::new(
                angle_deg => 0,
                start_color => 0x245f73,
                end_color => 0x0a2a3a,
                shift => 0.20,
            ),
            quad => $quad,
            quad_pos => Matrix3::Vec::from_xy(-12, 5),
        }, __PACKAGE__;

        return $self;
    }

    sub render($self, $renderer) {
        my $w = $self->{quad}->width;
        my $h = $self->{quad}->height;

        for my $y (0 .. $h - 1) {
            for my $x (0 .. $w - 1) {
                my $bg = $self->{gradient}->color_at_local($x, $y, $w, $h);
                my $cell_pos = $self->{quad_pos} + Matrix3::Vec::from_xy($x, -$y);
                $renderer->render_style($cell_pos, 1, -bg => $bg);
            }
        }
    }

    sub update($self, $delta_time, @events) {
        $self->{gradient}->advance($delta_time);

        for my $event (@events) {
            if ($event->type eq Event::Type::KEY_PRESS
                && $event->payload->char eq 'q') {
                return 0;
            }
        }

        return 1;
    }
}

package ZRogue::FPSWidget {
    use v5.36;

    sub new() {
        bless {
            fps => 0,
        }, __PACKAGE__;
    }

    sub update($self, $delta_time, @events) {
        if ($delta_time > 0) {
            $self->{fps} = 1 / $delta_time;
        }
        return 1;
    }

    sub render($self, $renderer) {
        my $text = sprintf "FPS %6.1f", $self->{fps};
        my $x = int(($renderer->width - 1) / 2);
        my $y = int($renderer->height / 2);
        $renderer->render_text(
            Matrix3::Vec::from_xy($x, $y),
            $text,
            -justify => 'right',
            -fg => 0x8cf29a,
            -bg => 0x0a0a0a,
        );
    }
}

package main {
    my $mapper = MaterialMapper::from_callback(sub ($material) {
        state %styles = (
            DEFAULT => { -fg => 0xaaaaaa, -bg => 0x0a0a0a, -attrs => 0 },
        );
        $styles{$material} // $styles{DEFAULT};
    });

    my $widget = ZRogue::Widget::new();
    my $fps = ZRogue::FPSWidget::new();
    my $loop = GameLoop::new($mapper, $widget, $fps);
    $loop->run();
}
