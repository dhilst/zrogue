use v5.36;
use utf8;

use Carp;
use Term::Cap;
use Term::ANSIColor;
use Time::HiRes qw(sleep);
use List::Util;
use Data::Dumper;
use Math::BigInt qw(bgcd);
use Time::HiRes;
use Benchmark qw(:all);

use FindBin qw($Bin);
use lib "$Bin";

use Termlib;
use Matrix3 qw($REFLECT_X $EAST $WEST $SOUTH $NORTH);
use Geometry3;
use Material;
use Views;
use Viewport;
use Input;
use Utils qw(aref);
use Renderers;
use SGR qw(:attrs);
use Quad;

package Menu {
    no autovivification;

    use POSIX;
    use FindBin qw($Bin);
    use lib "$Bin";

    use Matrix3 qw($EAST $WEST $SOUTH $NORTH);
    use Utils qw(getters);

    my $VIEW = <<'EOF';
┌──────────────────────────────────────────┐
│ Menu                                   $T│
├──────────────────────────────────────────┤
│$H MENU1        $P                        │
│$M MENU2        $L                        │
│$D MENU3                                  │
├──────────────────────────────────────────┤
│ Status: $R                               │
└──────────────────────────────────────────┘
EOF

#|-------------------------------|
    my @CYCLES = qw(H M D);
    my %NAMES = (
        H => 'MENU1',
        M => 'MENU2',
        D => 'MENU3',
    );

    getters qw(focus pos lastpos geo renderer z bg_quad bg_topleft);

    sub from_xyz(
        $x, $y, $z,
        $renderer
    ) {
        Menu::from_pos(Matrix3::Vec::from_xy($x, $y), $z, $renderer);
    }

    sub from_pos(
        $pos,
        $z,
        $renderer
    ) {
        my $geo = Geometry3::from_str($VIEW, -centerfy => 1);
        my ($minx, $maxx, $miny, $maxy);
        for my $po ($geo->@*) {
            my ($p, $value) = $po->@*;
            my ($x, $y) = $p->@*;
            my $len = length($value);
            $minx = $x if !defined $minx || $x < $minx;
            my $x_end = $x + $len - 1;
            $maxx = $x_end if !defined $maxx || $x_end > $maxx;
            $miny = $y if !defined $miny || $y < $miny;
            $maxy = $y if !defined $maxy || $y > $maxy;
        }
        my $bg_w = $maxx - $minx + 1;
        my $bg_h = $maxy - $miny + 1;
        my $bg_quad = Quad::from_wh($bg_w, $bg_h, 'MENU_BG');
        my $bg_topleft = Matrix3::Vec::from_xy($minx, $maxy);
        bless {
            focus => undef,
            status => undef,
            time => POSIX::strftime("%H:%M:%S", localtime),
            geo => $geo,
            pos => $pos,
            lastpos => $pos->copy,
            renderer => $renderer,
            bg_quad => $bg_quad,
            bg_topleft => $bg_topleft,
            z => $z,
        }, __PACKAGE__;
    }

    sub _render_shadow_at($self, $pos, $material) {
        my $top_left = $pos + $self->bg_topleft;
        my ($x0, $y0) = $top_left->@*;
        my $w = $self->bg_quad->width;
        my $h = $self->bg_quad->height;

        my $right_x = $x0 + $w;
        my $right_top = $y0 - 1;
        my $right_bottom = $y0 - $h;
        $self->renderer->render_line(
            Matrix3::Vec::from_xy($right_x, $right_top),
            Matrix3::Vec::from_xy($right_x, $right_bottom),
            $material,
        );

        return if $w < 2;
        my $bottom_y = $y0 - $h;
        my $bottom_left = $x0 + 1;
        my $bottom_right = $x0 + $w - 1;
        $self->renderer->render_line(
            Matrix3::Vec::from_xy($bottom_left, $bottom_y),
            Matrix3::Vec::from_xy($bottom_right, $bottom_y),
            $material,
        );
    }

    sub update($self, @events) {
        my $changed = 0;
        my $idx = Utils::Array::index_of($self->{focus} // 'D', @CYCLES);
        for my $event (@events) {
            my $char = $event->payload->char;
            if ($char eq 'k') {
                $self->{focus} = $CYCLES[--$idx % @CYCLES];
                $changed = 1;
            } elsif ($char eq 'j') {
                $self->{focus} = $CYCLES[++$idx % @CYCLES];
                $changed = 1;
            } elsif ($char eq 'K') {
                $self->{pos} *= $NORTH;
                $changed = 1;
            } elsif ($char eq 'J') {
                $self->{pos} *= $SOUTH;
                $changed = 1;
            } elsif ($char eq 'H') {
                $self->{pos} *= $WEST;
                $changed = 1;
            } elsif ($char eq 'L') {
                $self->{pos} *= $EAST;
                $changed = 1;
            } elsif ($event->payload->code eq 0x0a && defined $self->focus) {
                my $status = sprintf "%s selected", $NAMES{$self->{focus}};
                if (!defined $self->{status} || $self->{status} ne $status) {
                    $self->{status} = $status;
                    $changed = 1;
                }
            }
        }

        my $now = POSIX::strftime("%H:%M:%S", localtime);
        if (!defined $self->{time} || $self->{time} ne $now) {
            $self->{time} = $now;
            $changed = 1;
        }
        $changed;
    }

    sub render($self) {
        # ▶ ▷
        my $lastpos = $self->lastpos->copy;
        $self->_render_shadow_at($self->pos, 'SHADOW_BG');
        $self->renderer->render_quad($self->pos + $self->bg_topleft, $self->bg_quad);
        $self->renderer->render_geometry($self->pos, $self->geo);
        $self->renderer->render_fmt($self->pos + $self->geo->points->{P}, "pos:     %s", $self->pos);
        $self->renderer->render_fmt($self->pos + $self->geo->points->{L}, "lastpos: %s", $lastpos);

        if ($self->focus) {
            $self->renderer->render_text($self->pos + $self->geo->points->{$self->focus}, ' ▶');
            $self->renderer->render_text($self->pos + $self->geo->points->{$_}, ' ▷')
                for grep { $_ ne $self->focus } @CYCLES;
        } else {
            $self->renderer->render_text($self->pos + $self->geo->points->{$_}, ' ▷')
                for @CYCLES;
        }
        if (defined $self->{status}) {
            $self->renderer->render_text($self->pos + $self->geo->points->{R}, $self->{status})
        }
        my $time = $self->{time} // POSIX::strftime("%H:%M:%S", localtime);
        $self->renderer->render_text($self->pos + $self->geo->points->{T}, $time,
            -justify => 'right');
    }

    sub erase($self) {
        my $blank = Quad::from_wh($self->bg_quad->width, $self->bg_quad->height, 'DEFAULT_BG');
        $self->_render_shadow_at($self->lastpos, 'DEFAULT_BG');
        $self->renderer->render_quad($self->lastpos + $self->bg_topleft, $blank);
        $self->renderer->erase_geometry($self->lastpos, $self->geo);
        $self->{lastpos} = $self->pos->copy;
    }


}

package Question {
    my $VIEW = <<'EOF';
┌────────────────────────────────────────────────────────────────┐
│                               $QUESTION                        │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│                                                                │
│                        $YES        $NO                         │
│                                                                │
│                               $ANS                             │
└────────────────────────────────────────────────────────────────┘
EOF

    use Utils qw(getters);

    getters qw(
        answer
        focus
        geo
        lastpos
        pos
        question
        renderer
        bg_quad
        bg_topleft
        z
    );

    sub from_xyz($x, $y, $z, $question, $renderer) {
        my $pos = Matrix3::Vec::from_xy($x, $y);
        my $geo = Geometry3::from_str($VIEW, -centerfy => 1);
        my ($minx, $maxx, $miny, $maxy);
        for my $po ($geo->@*) {
            my ($p, $value) = $po->@*;
            my ($x, $y) = $p->@*;
            my $len = length($value);
            $minx = $x if !defined $minx || $x < $minx;
            my $x_end = $x + $len - 1;
            $maxx = $x_end if !defined $maxx || $x_end > $maxx;
            $miny = $y if !defined $miny || $y < $miny;
            $maxy = $y if !defined $maxy || $y > $maxy;
        }
        my $bg_w = $maxx - $minx + 1;
        my $bg_h = $maxy - $miny + 1;
        my $bg_quad = Quad::from_wh($bg_w, $bg_h, 'QUESTION_BG');
        my $bg_topleft = Matrix3::Vec::from_xy($minx, $maxy);
        bless {
            focus => "NO",
            geo => $geo,
            pos => $pos,
            lastpos => $pos->copy,
            renderer => $renderer,
            bg_quad => $bg_quad,
            bg_topleft => $bg_topleft,
            question => $question,
            answer => undef,
            z => $z,
        }, __PACKAGE__;
    }

    sub update($self, @events) {
        my $changed = 0;
        for my $event (@events) {
            my $char = $event->payload->char;
            if ($char eq "h") {
                if ($self->{focus} ne "YES") {
                    $self->{focus} = "YES";
                    $changed = 1;
                }
            } elsif ($char eq "l") {
                if ($self->{focus} ne "NO") {
                    $self->{focus} = "NO";
                    $changed = 1;
                }
            } elsif ($event->payload->code == 0x0a) {
                my $answer = sprintf "%3s", $self->focus;
                if (!defined $self->{answer} || $self->{answer} ne $answer) {
                    $self->{answer} = $answer;
                    $changed = 1;
                }
            }
        }
        $changed;
    }
    
    sub render($self) {
        # $self->renderer->erase_geometry($self->pos, $self->geo);
        $self->renderer->render_line(
            $self->pos + $self->bg_topleft + Matrix3::Vec::from_xy($self->bg_quad->width, -1),
            $self->pos + $self->bg_topleft + Matrix3::Vec::from_xy($self->bg_quad->width, -$self->bg_quad->height),
            'SHADOW_BG',
        );
        if ($self->bg_quad->width > 1) {
            $self->renderer->render_line(
                $self->pos + $self->bg_topleft + Matrix3::Vec::from_xy(1, -$self->bg_quad->height),
                $self->pos + $self->bg_topleft + Matrix3::Vec::from_xy($self->bg_quad->width - 1, -$self->bg_quad->height),
                'SHADOW_BG',
            );
        }
        $self->renderer->render_quad($self->pos + $self->bg_topleft, $self->bg_quad);
        $self->renderer->render_geometry($self->pos, $self->geo);
        $self->renderer->render_text(
            $self->pos + $self->geo->points->{QUESTION},
            $self->question,
            -justify => 'center');

        if ($self->focus eq "YES") {
            $self->renderer->render_text($self->pos + $self->geo->points->{YES}, "> YES");
            $self->renderer->render_text($self->pos + $self->geo->points->{NO},  "  NO ");
        } elsif ($self->focus eq "NO") {
            $self->renderer->render_text($self->pos + $self->geo->points->{YES}, "  YES");
            $self->renderer->render_text($self->pos + $self->geo->points->{NO},  "> NO ");
        }

        if ($self->answer) {
            $self->renderer->render_text($self->pos + $self->geo->points->{ANS}, $self->answer);
        }
    }

    sub erase($self) {
        my $blank = Quad::from_wh($self->bg_quad->width, $self->bg_quad->height, 'DEFAULT_BG');
        $self->renderer->render_line(
            $self->lastpos + $self->bg_topleft + Matrix3::Vec::from_xy($self->bg_quad->width, -1),
            $self->lastpos + $self->bg_topleft + Matrix3::Vec::from_xy($self->bg_quad->width, -$self->bg_quad->height),
            'DEFAULT_BG',
        );
        if ($self->bg_quad->width > 1) {
            $self->renderer->render_line(
                $self->lastpos + $self->bg_topleft + Matrix3::Vec::from_xy(1, -$self->bg_quad->height),
                $self->lastpos + $self->bg_topleft + Matrix3::Vec::from_xy($self->bg_quad->width - 1, -$self->bg_quad->height),
                'DEFAULT_BG',
            );
        }
        $self->renderer->render_quad($self->lastpos + $self->bg_topleft, $blank);
        $self->renderer->erase_geometry($self->lastpos, $self->geo);
        $self->{lastpos} = $self->pos->copy;
    }

}

my $term = Termlib::new();
my $COLS = $term->cols;
my $ROWS = $term->rows;

# Set origin to screen center and reflect over x axis
# st y increases upwards in world_space
my $terminal_space = Matrix3::translate(($COLS - 1)/2, $ROWS/2)
            ->mul_mat_inplace($REFLECT_X);

my $origin = Matrix3::Vec::from_xy(0, 0);
my $inp = Input::new();
my $dt = Time::HiRes::time();

my $mapper = Material::from_callback(sub ($material) {
    return { -bg => 0xcccccc } 
        if $material eq 'STEEL';

    return { -bg => 0xaa00aa, -attrs => ATTR_BOLD }
        if $material eq 'MENU_BG';

    return { -bg => 0x000000 }
        if $material eq 'QUESTION_BG';

    return { -bg => 0x303030 }
        if $material eq 'SHADOW_BG';

    return { -fg => 0xaaaaaa, -bg => 0x0a0a0a, -attrs => 0 }
        if $material eq 'DEFAULT';

    return { -fg => 0xaaaaaa, -bg => 0x0a0a0a, -attrs => 0 };
});

# my $renderer = Renderers::Naive::new($terminal_space, $mapper, ' ');
my $renderer = Renderers::DoubleBuffering::new($terminal_space, $ROWS, $COLS - 1, $mapper, ' ');
$renderer->initscr();

my $hello_pos = Matrix3::Vec::from_xy(0, -10);
$renderer->render_style($hello_pos, length("Hello world"), -bg => 0x0000ff);
$renderer->render_text($hello_pos, "Hello world", -fg => 0xff0000, -attrs => ATTR_BOLD);
my $line_a = Matrix3::Vec::from_xy(-25, 14);
my $line_b = Matrix3::Vec::from_xy(25, 6);
my $line_c = Matrix3::Vec::from_xy(-30, -8);
my $line_d = Matrix3::Vec::from_xy(-5, 12);
$renderer->render_line($line_a, $line_b, 'MENU_BG');
$renderer->render_line($line_c, $line_d, 'SHADOW_BG');
$renderer->flush();

my $question = Question::from_xyz(0, 20, 1, "Hello?", $renderer);
my $menu = Menu::from_xyz(10, 0, 2, $renderer);

my @wids = (
    $question,
    $menu,
);

sub wids {
    sort { $b->{z} <=> $a->{z} } @wids;
}

sub render_all {
    $_->render() for wids;
    $renderer->flush();
}

sub erase_all {
    $_->erase() for @wids;
}

render_all();
OUT:
while (1) {
    my @events = $inp->poll(3);
    my $z_changed = 0;
    for my $event (@events) {
        if ($event->type eq Event::Type::KEY_PRESS
            && $event->payload->code eq Event::KeyCode::ESC) {
            last OUT;
        } elsif ($event->type eq Event::Type::KEY_PRESS
            && $event->payload->char eq 's') {
            ($menu->{z}, $question->{z}) = ($question->z, $menu->z);
            $z_changed = 1;
        }
    }
    my @changed = grep { $_->update(@events) } @wids;
    if ($z_changed) {
        erase_all();
        render_all();
        next;
    }
    if (@changed) {
        $_->erase() for @changed;
        my %changed = map { $_ => 1 } @changed;
        $_->render() for grep { $changed{$_} } wids;
        $renderer->flush();
    }
}
