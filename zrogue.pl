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
use Skin;
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
        focus pos lastpos geo renderer z bg_topleft surface clear_surface
        text_input checkbox_input select_input active_input
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
        my $layout = Skin::layout($geo);
        my $maxx = $layout->{maxx};
        my $maxy = $layout->{maxy};
        my $bg_topleft = $layout->{topleft};
        my $mapper = $renderer->mapper;
        my $def_style = $mapper->style('DEFAULT');
        my @defaults = (
            ord(' '),
            $def_style->{-fg} // -1,
            $def_style->{-bg} // -1,
            $def_style->{-attrs} // -1,
        );
        my ($surface, $clear_surface) = Skin::from_geometry($geo,
            -mapper => $mapper,
            -bg => 'MENU_BG',
            -shadow => 'SHADOW_BG',
            -defaults => \@defaults,
        );
        my $text_input = TextInput::new(
            -max_from => [$geo->points->{INP}, $maxx],
            -material_focus => 'INPUT_FOCUS',
            -material_blur => 'INPUT_BLUR',
        );
        my $checkbox_input = CheckboxInput::new(
            -material_focus => 'INPUT_FOCUS',
            -material_blur => 'INPUT_BLUR',
        );
        my $select_input = SelectInput::new(
            -options => [qw(ONE TWO THREE)],
            -max_from => [$geo->points->{SV}, $maxx],
            -material_focus => 'INPUT_FOCUS',
            -material_blur => 'INPUT_BLUR',
        );
        bless {
            focus => undef,
            status => undef,
            time => POSIX::strftime("%H:%M:%S", localtime),
            geo => $geo,
            pos => $pos,
            lastpos => $pos->copy,
            renderer => $renderer,
            bg_topleft => $bg_topleft,
            surface => $surface,
            clear_surface => $clear_surface,
            text_input => $text_input,
            checkbox_input => $checkbox_input,
            select_input => $select_input,
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
                    $self->{text_input}->blur;
                    $self->{checkbox_input}->blur;
                    $self->{select_input}->blur;
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
                    $self->{text_input}->focus;
                    $self->{checkbox_input}->blur;
                    $self->{select_input}->blur;
                    $changed = 1;
                } elsif ($self->{focus} eq 'B') {
                    $self->{active_input} = 'checkbox';
                    $self->{checkbox_input}->clear_flags;
                    $self->{text_input}->blur;
                    $self->{checkbox_input}->focus;
                    $self->{select_input}->blur;
                    $changed = 1;
                } elsif ($self->{focus} eq 'S') {
                    $self->{active_input} = 'select';
                    $self->{select_input}->clear_flags;
                    $self->{text_input}->blur;
                    $self->{checkbox_input}->blur;
                    $self->{select_input}->focus;
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
        $self->{text_input}->render(
            $self->renderer,
            $self->pos + $self->geo->points->{INP},
        );
        $self->{checkbox_input}->render(
            $self->renderer,
            $self->pos + $self->geo->points->{C},
        );
        $self->{select_input}->render(
            $self->renderer,
            $self->pos + $self->geo->points->{SV},
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
        bg_topleft
        surface
        clear_surface
        z
    );

    sub from_xyz($x, $y, $z, $question, $renderer) {
        my $pos = Matrix3::Vec::from_xy($x, $y);
        my $geo = Geometry3::from_str($VIEW, -centerfy => 1);
        my $layout = Skin::layout($geo);
        my $maxy = $layout->{maxy};
        my $bg_topleft = $layout->{topleft};
        my $mapper = $renderer->mapper;
        my $def_style = $mapper->style('DEFAULT');
        my @defaults = (
            ord(' '),
            $def_style->{-fg} // -1,
            $def_style->{-bg} // -1,
            $def_style->{-attrs} // -1,
        );
        my ($surface, $clear_surface) = Skin::from_geometry($geo,
            -mapper => $mapper,
            -bg => 'QUESTION_BG',
            -shadow => 'SHADOW_BG',
            -defaults => \@defaults,
        );
        my $geo_offset = $layout->{geo_offset};
        $surface->render_text(
            $geo->points->{QUESTION} + $geo_offset,
            $question,
            -justify => 'center');
        bless {
            focus => "NO",
            geo => $geo,
            pos => $pos,
            lastpos => $pos->copy,
            renderer => $renderer,
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
    state %map = (
        MENU_BG => { -bg => 0xaa00aa, -attrs => ATTR_BOLD },
        QUESTION_BG => { -bg => 0x000000 },
        SHADOW_BG => { -bg => 0x303030 },
        INPUT_FOCUS => {  -attrs => ATTR_BOLD | ATTR_REVERSE },
        INPUT_BLUR => { -attrs => 0 },
        DEFAULT => { -fg => 0xaaaaaa, -bg => 0x0a0a0a, -attrs => 0 },
    );

    $map{$material} // $map{DEFAULT};
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
