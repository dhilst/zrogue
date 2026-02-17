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
use MaterialMapper;
use Views;
use Viewport;
use Input;
use Utils qw(aref);
use Renderers;
use Surface;
use SGR qw(:attrs);
use Quad;
use TextInput;
use CheckboxInput;
use SelectInput;

package Menu {
    no autovivification;

    use POSIX;
    use FindBin qw($Bin);
    use lib "$Bin";

    use SGR qw(:attrs);
    use Matrix3 qw($EAST $WEST $SOUTH $NORTH);
    use Utils qw(getters);

    my $VIEW = <<'EOF';
┌──────────────────────────────────────────┐
│ Menu                                   $T│
├──────────────────────────────────────────┤
│$H MENU1        $P                        │
│$M MENU2        $L                        │
│$I INPUT: $INP                            │
│$B CHECK: $C                              │
│$S SELECT: $SV                            │
│$D MENU3                                  │
├──────────────────────────────────────────┤
│ Status: $R                               │
└──────────────────────────────────────────┘
EOF

#|-------------------------------|
    my @CYCLES = qw(H M I B S D);
    my %NAMES = (
        H => 'MENU1',
        M => 'MENU2',
        D => 'MENU3',
    );

    getters qw(
        focus pos lastpos geo renderer z bg_quad bg_topleft surface clear_surface
        text_input checkbox_input select_input active_input select_max
    );

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
        my $input_pos = $geo->points->{INP};
        my $input_max = defined $input_pos ? ($maxx - $input_pos->x - 1) : undef;
        $input_max = undef if defined $input_max && $input_max < 0;
        my $select_pos = $geo->points->{SV};
        my $select_max = defined $select_pos ? ($maxx - $select_pos->x - 1) : undef;
        $select_max = undef if defined $select_max && $select_max < 0;
        my $bg_quad = Quad::from_wh($bg_w, $bg_h, 'MENU_BG');
        my $bg_topleft = Matrix3::Vec::from_xy($minx, $maxy);
        my $surface_w = $bg_w + 1;
        my $surface_h = $bg_h + 1;
        my $material = $renderer->mapper;
        my $def_style = $material->style('DEFAULT');
        my @defaults = (
            ord(' '),
            $def_style->{-fg} // -1,
            $def_style->{-bg} // -1,
            $def_style->{-attrs} // -1,
        );
        my $surface = Surface::new($surface_h, $surface_w,
            -material => $material,
            -defaults => \@defaults);
        my $clear_surface = Surface::new($surface_h, $surface_w,
            -material => $material,
            -defaults => \@defaults);
        my $geo_offset = Matrix3::Vec::from_xy(-$bg_topleft->x, -$bg_topleft->y);

        my $clear_quad = Quad::from_wh($surface_w, $surface_h, 'DEFAULT_BG');
        $surface->render_quad(Matrix3::Vec::from_xy(0, 0), $clear_quad);
        $surface->render_quad(Matrix3::Vec::from_xy(0, 0), $bg_quad);
        $surface->render_line(
            Matrix3::Vec::from_xy($bg_w, -1),
            Matrix3::Vec::from_xy($bg_w, -$bg_h),
            'SHADOW_BG',
        );
        if ($bg_w > 1) {
            $surface->render_line(
                Matrix3::Vec::from_xy(1, -$bg_h),
                Matrix3::Vec::from_xy($bg_w - 1, -$bg_h),
                'SHADOW_BG',
            );
        }
        $surface->render_geometry($geo_offset, $geo);

        $clear_surface->render_quad(Matrix3::Vec::from_xy(0, 0), $clear_quad);
        my $text_input = TextInput::new(-max_len => $input_max);
        my $checkbox_input = CheckboxInput::new();
        my $select_input = SelectInput::new(-options => [qw(ONE TWO THREE)]);
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
            surface => $surface,
            clear_surface => $clear_surface,
            text_input => $text_input,
            checkbox_input => $checkbox_input,
            select_input => $select_input,
            select_max => $select_max,
            active_input => undef,
            z => $z,
        }, __PACKAGE__;
    }

    sub update($self, @events) {
        my $changed = 0;
        my $idx = Utils::Array::index_of($self->{focus} // 'D', @CYCLES);
        my @input_events;
        for my $event (@events) {
            my $char = $event->payload->char;
            my $code = $event->payload->code;
            if ($self->{active_input}) {
                if ($code == Event::KeyCode::ESC) {
                    $self->{active_input} = undef;
                    $changed = 1;
                    next;
                }
                push @input_events, $event;
                next;
            }
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
            } elsif ($code == Event::KeyCode::ENTER && defined $self->focus) {
                if ($self->{focus} eq 'I') {
                    $self->{active_input} = 'text';
                    $self->{text_input}->clear_flags;
                    $changed = 1;
                } elsif ($self->{focus} eq 'B') {
                    $self->{active_input} = 'checkbox';
                    $self->{checkbox_input}->clear_flags;
                    $changed = 1;
                } elsif ($self->{focus} eq 'S') {
                    $self->{active_input} = 'select';
                    $self->{select_input}->clear_flags;
                    $changed = 1;
                } else {
                    my $status = sprintf "%s selected", $NAMES{$self->{focus}};
                    if (!defined $self->{status} || $self->{status} ne $status) {
                        $self->{status} = $status;
                        $changed = 1;
                    }
                }
            }
        }

        if ($self->{active_input}) {
            if ($self->{active_input} eq 'text') {
                $changed = 1 if $self->{text_input}->update(@input_events);
            } elsif ($self->{active_input} eq 'checkbox') {
                $changed = 1 if $self->{checkbox_input}->update(@input_events);
            } elsif ($self->{active_input} eq 'select') {
                $changed = 1 if $self->{select_input}->update(@input_events);
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
        $self->renderer->render_buffer($self->pos + $self->bg_topleft, $self->{surface}->buffer);
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
        my %input_opts = $self->{active_input} && $self->{active_input} eq 'text'
            ? (-attrs => ATTR_REVERSE)
            : ();
        my $input_text = $self->{text_input}->text;
        if (defined $self->{text_input}->max_len) {
            my $pad = $self->{text_input}->max_len - length($input_text);
            $input_text .= ' ' x $pad if $pad > 0;
        }
        $self->renderer->render_text(
            $self->pos + $self->geo->points->{INP},
            $input_text,
            %input_opts,
        );
        my $check = $self->{checkbox_input}->checked ? '[x]' : '[ ]';
        my %check_opts = $self->{active_input} && $self->{active_input} eq 'checkbox'
            ? (-attrs => ATTR_REVERSE)
            : ();
        $self->renderer->render_text(
            $self->pos + $self->geo->points->{C},
            $check,
            %check_opts,
        );
        my $options = $self->{select_input}->options;
        my $sel_text = $options->[ $self->{select_input}->index ];
        if (defined $self->{select_max}) {
            $sel_text = substr($sel_text, 0, $self->{select_max})
                if length($sel_text) > $self->{select_max};
            my $pad = $self->{select_max} - length($sel_text);
            $sel_text .= ' ' x $pad if $pad > 0;
        }
        my %select_opts = $self->{active_input} && $self->{active_input} eq 'select'
            ? (-attrs => ATTR_REVERSE)
            : ();
        $self->renderer->render_text(
            $self->pos + $self->geo->points->{SV},
            $sel_text,
            %select_opts,
        );
        my $time = $self->{time} // POSIX::strftime("%H:%M:%S", localtime);
        $self->renderer->render_text($self->pos + $self->geo->points->{T}, $time,
            -justify => 'right');
    }

    sub erase($self) {
        $self->renderer->render_buffer($self->lastpos + $self->bg_topleft, $self->{clear_surface}->buffer);
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
        surface
        clear_surface
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
        my $surface_w = $bg_w + 1;
        my $surface_h = $bg_h + 1;
        my $material = $renderer->mapper;
        my $def_style = $material->style('DEFAULT');
        my @defaults = (
            ord(' '),
            $def_style->{-fg} // -1,
            $def_style->{-bg} // -1,
            $def_style->{-attrs} // -1,
        );
        my $surface = Surface::new($surface_h, $surface_w,
            -material => $material,
            -defaults => \@defaults);
        my $clear_surface = Surface::new($surface_h, $surface_w,
            -material => $material,
            -defaults => \@defaults);
        my $geo_offset = Matrix3::Vec::from_xy(-$bg_topleft->x, -$bg_topleft->y);

        $surface->render_quad(Matrix3::Vec::from_xy(0, 0), $bg_quad);
        $surface->render_line(
            Matrix3::Vec::from_xy($bg_w, -1),
            Matrix3::Vec::from_xy($bg_w, -$bg_h),
            'SHADOW_BG',
        );
        if ($bg_w > 1) {
            $surface->render_line(
                Matrix3::Vec::from_xy(1, -$bg_h),
                Matrix3::Vec::from_xy($bg_w - 1, -$bg_h),
                'SHADOW_BG',
            );
        }
        $surface->render_geometry($geo_offset, $geo);
        $surface->render_text(
            $geo->points->{QUESTION} + $geo_offset,
            $question,
            -justify => 'center');

        my $clear_quad = Quad::from_wh($surface_w, $surface_h, 'DEFAULT_BG');
        $clear_surface->render_quad(Matrix3::Vec::from_xy(0, 0), $clear_quad);
        bless {
            focus => "NO",
            geo => $geo,
            pos => $pos,
            lastpos => $pos->copy,
            renderer => $renderer,
            bg_quad => $bg_quad,
            bg_topleft => $bg_topleft,
            surface => $surface,
            clear_surface => $clear_surface,
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
        $self->renderer->render_buffer($self->pos + $self->bg_topleft, $self->{surface}->buffer);

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
        $self->renderer->render_buffer($self->lastpos + $self->bg_topleft, $self->{clear_surface}->buffer);
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
my $resized = 0;
local $SIG{WINCH} = sub { $resized = 1; };

my $mapper = MaterialMapper::from_callback(sub ($material) {
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
my $line_a = Matrix3::Vec::from_xy(-25, 14);
my $line_b = Matrix3::Vec::from_xy(25, 6);
my $line_c = Matrix3::Vec::from_xy(-30, -8);
my $line_d = Matrix3::Vec::from_xy(-5, 12);

my $question = Question::from_xyz(0, 20, 1, "Hello?", $renderer);
my $menu = Menu::from_xyz(10, 0, 2, $renderer);

my @wids = (
    $question,
    $menu,
);

sub render_static {
    $renderer->render_style($hello_pos, length("Hello world"), -bg => 0x0000ff);
    $renderer->render_text($hello_pos, "Hello world", -fg => 0xff0000, -attrs => ATTR_BOLD);
    $renderer->render_line($line_a, $line_b, 'MENU_BG');
    $renderer->render_line($line_c, $line_d, 'SHADOW_BG');
}

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

sub handle_resize {
    $resized = 0;
    $COLS = $term->cols;
    $ROWS = $term->rows;
    $terminal_space = Matrix3::translate(($COLS - 1)/2, $ROWS/2)
                ->mul_mat_inplace($REFLECT_X);
    $renderer = Renderers::DoubleBuffering::new($terminal_space, $ROWS, $COLS - 1, $mapper, ' ');
    $renderer->initscr();
    $_->{renderer} = $renderer for @wids;
    $_->{lastpos} = $_->{pos}->copy for @wids;
    render_static();
    render_all();
}

render_static();
render_all();
OUT:
while (1) {
    my @events = $inp->poll(3);
    if ($resized) {
        handle_resize();
        next;
    }
    my $z_changed = 0;
    for my $event (@events) {
        if ($event->type eq Event::Type::KEY_PRESS
            && $event->payload->char eq 'q') {
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
        $_->render() for grep { $changed{$_} } wids();
        $renderer->flush();
    }
}
