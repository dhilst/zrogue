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
        if ($self->lastpos ne $self->pos) {
            $self->renderer->erase_geometry($self->lastpos, $self->geo, '.');
            $self->{lastpos} = $self->pos->copy;
        }
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

}

my $term = Termlib::new();
my $COLS = $term->cols;
my $ROWS = $term->rows;

# Set origin to screen center and reflect over x axis
# st y increases upwards in world_space
my $terminal_space = Matrix3::translate(($COLS - 1)/2, $ROWS/2)
            ->mul_mat_inplace($REFLECT_X);

my $origin = Matrix3::Vec::from_xy(0, 0) * $terminal_space;

$term->initscr(' ');
$term->write_color("hello world",
    $origin->@*,
    0x00ff00,
    0xff00ff,
    ATTR_BOLD | ATTR_ITALIC | ATTR_UNDERLINE | ATTR_REVERSE);

# my $inp = Input::new();
# 
# my $dt = Time::HiRes::time();
# 
# my $renderer = Renderers::Naive::new($terminal_space);
# $renderer->initscr();
# 
# my $menu = Menu::from_xyz(10,10,0, $renderer);
# $menu->render();
# 
# my $question = Question::from_xyz(10,20,-1,"Is anybody in there?", $renderer);
# $question->render();
# 
# my @WIDS = (
#     $menu, 
#     $question
# );
# 
# sub wids {
#     sort { $a->z <=> $b->z } @WIDS;
# }
# 
# # # # render_text($pos, '@', $term);
# while (1) {
#     my @events = $inp->poll(1);
#     my $dt = Time::HiRes::time() - $dt;
#     # last unless @events;
#     $_->update($dt, @events) for @WIDS;
#     for my $event (@events) {
#         if ($event->payload->char eq 'S') {
#             ($question->{z}, $menu->{z}) = ($menu->z, $question->z);
#         }
# 
#     }
#     $_->render() for wids;
#     $renderer->flush();
# }
#  
# # $term->initscr(' ');
# # my $inventory = Geometry3::from_str($Views::INVENTORY, -centerfy => 1);
# # render_geometry($origin, $inventory, $term);
# # render_text($inventory->points->{NAME}, "LEON ", $term);
# # render_text($inventory->points->{FILE}, "> FILE", $term);
# # render_text($inventory->points->{MAP}, "> MAP", $term);
# # render_text($inventory->points->{ITEM}, "> ITEM", $term);
# # render_text($inventory->points->{EXIT}, "> EXIT", $term);
# # render_text($inventory->points->{HAND}, "> 9mm Pistol", $term, -justify => 'center');
# # render_text($inventory->points->{PKT}, "> Lighter", $term, -justify => 'center');
# # render_text($inventory->regions->{HEALTH}->bottomright, "Fine", $term, -justify => 'right');
# # render_text($inventory->regions->{STATUS}->center, "Some item image here", $term, -justify => 'center');
# # render_text($inventory->regions->{TEXT}->center, "Some item text description here", $term, -justify => 'center');
# # render_text($inventory->regions->{INVENTORY}->topleft, "List of items in invetory", $term,);
