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
use Geometry4;
use Views;
use Viewport;
use Input;
use Utils qw(aref);
use Renderers;
use SGR qw(:attrs);

package Menu {
    no autovivification;

    use POSIX;
    use FindBin qw($Bin);
    use lib "$Bin";

    use Matrix3 qw($EAST $WEST $SOUTH $NORTH);
    use Utils qw(getters);

    my $VIEW = <<'EOF';
,------------------------------------------,
| Menu                                   $T|
|------------------------------------------|
|$H MENU1        $P                        |
|$M MENU2        $L                        |
|$D MENU3                                  |
|------------------------------------------|
| Status: $R                               |
'------------------------------------------'
EOF

#|-------------------------------|
    my @CYCLES = qw(H M D);
    my %NAMES = (
        H => 'MENU1',
        M => 'MENU2',
        D => 'MENU3',
    );

    getters qw(focus pos lastpos geo renderer z);

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
        bless {
            focus => undef,
            status => undef,
            geo => $geo,
            pos => $pos,
            lastpos => $pos->copy,
            renderer => $renderer,
            z => $z,
        }, __PACKAGE__;
    }

    sub update($self, $dt, @events) {
        my $idx = Utils::Array::index_of($self->{focus} // 'D', @CYCLES);
        for my $event (@events) {
            my $char = $event->payload->char;
            if ($char eq 'k') {
                $self->{focus} = $CYCLES[--$idx % @CYCLES];
            } elsif ($char eq 'j') {
                $self->{focus} = $CYCLES[++$idx % @CYCLES];
            } elsif ($char eq 'K') {
                $self->{pos} *= $NORTH;
            } elsif ($char eq 'J') {
                $self->{pos} *= $SOUTH;
            } elsif ($char eq 'H') {
                $self->{pos} *= $WEST;
            } elsif ($char eq 'L') {
                $self->{pos} *= $EAST;
            } elsif ($event->payload->code eq 0x0a && defined $self->focus) {
                $self->{status} = sprintf "%s selected", $NAMES{$self->{focus}};
            }
        }

    }

    sub render($self) {
        # ▶ ▷
        my $lastpos = $self->lastpos->copy;
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
        $self->renderer->render_text($self->pos + $self->geo->points->{T}, POSIX::strftime("%H:%M:%S", localtime),
            -justify => 'right');
    }

    sub erase($self) {
        $self->renderer->erase_geometry($self->lastpos, $self->geo);
        $self->{lastpos} = $self->pos->copy;
    }


}

package Question {
    my $VIEW = <<'EOF';
+----------------------------------------------------------------+
|                               $QUESTION                        |
|----------------------------------------------------------------|
|                                                                |
|                                                                |
|                        $YES        $NO                         |
|                                                                |
|                               $ANS                             |
|________________________________________________________________|
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
        z
    );

    sub from_xyz($x, $y, $z, $question, $renderer) {
        my $pos = Matrix3::Vec::from_xy($x, $y);
        my $geo = Geometry3::from_str($VIEW, -centerfy => 1);
        bless {
            focus => "NO",
            geo => $geo,
            pos => $pos,
            renderer => $renderer,
            question => $question,
            answer => undef,
            z => $z,
        }, __PACKAGE__;
    }

    sub update($self, $dt, @events) {
        for my $event (@events) {
            my $char = $event->payload->char;
            if ($char eq "h") {
                $self->{focus} = "YES";
            } elsif ($char eq "l") {
                $self->{focus} = "NO";
            } elsif ($event->payload->code == 0x0a) {
                $self->{answer} = sprintf "%3s", $self->focus;
            }
        }
    }
    
    sub render($self) {
        # $self->renderer->erase_geometry($self->pos, $self->geo);
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
        $self->renderer->erase_geometry($self->pos, $self->geo);
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

# my $renderer = Renderers::Naive::new($terminal_space);
my $renderer = Renderers::DoubleBuffering::new($terminal_space, $ROWS, $COLS - 1);
$renderer->initscr();

my $hello_pos = Matrix3::Vec::from_xy(0, -10);
$renderer->render_style($hello_pos, length("Hello world"), -bg => 0x0000ff);
$renderer->render_text($hello_pos, "Hello world", -fg => 0xff0000, -attrs => ATTR_BOLD);
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

sub update_all($dt, @events) {
    $_->update($dt, @events) for @wids;
}

sub render_all {
    $_->render() for wids;
    $renderer->flush();
}

sub erase_all {
    $_->erase() for @wids;
}

render_all();
while (1) {
    my @events = $inp->poll(1);
    for my $event (@events) {
        if ($event->type eq Event::Type::KEY_PRESS
            && $event->payload->char eq 's') {
            ($menu->{z}, $question->{z}) = ($question->z, $menu->z);
        }
    }
    update_all(1/60, @events);
    erase_all();
    render_all();
}
