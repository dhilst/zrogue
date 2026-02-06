use v5.36;
use utf8;

use Carp;
use Term::Cap;
use Term::ANSIColor;
use Time::HiRes qw(sleep);
use List::Util;
use Data::Dumper;
use Math::BigInt qw(bgcd);
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

my $term = Termlib->new();

 
my $COLS = $term->cols;
my $ROWS = $term->rows;

sub v($x,$y) { Matrix3::Vec::from_xy($x, $y) }

# Set origin to screen center
my $terminal_space = 
        Matrix3::translate(($COLS - 1)/2, $ROWS/2)
            ->mul_mat_inplace($REFLECT_X);

my $origin = Matrix3::Vec::from_xy(0, 0);
my $terminal_origin =
    $origin->copy->mul_mat_inplace($terminal_space);

sub render_geometry($at_vec, $geo, $term) {
    use integer;
    my $coord_mapper = $terminal_space * Matrix3::translate($at_vec->@*);
    for my $point ($geo->@*) {
        my ($pos_vec, $value) = $point->@*;
        $term->write_vec($value, $pos_vec * $coord_mapper);
    }
}

sub erase_geometry($at_vec, $geo, $char, $term) {
    use integer;
    my $coord_mapper = $terminal_space * Matrix3::translate($at_vec->@*);
    for my $point ($geo->@*) {
        my ($pos_vec, $value) = $point->@*;
        $term->write_vec($char x length($value), $pos_vec * $coord_mapper);
    }
}

sub render_text($at_vec, $text, $term, %opts) {
    use integer;
    $opts{-justify} //= 'left';
    if ($opts{-justify} eq 'center') {
        my $T = Matrix3::translate(- length($text) / 2, 0);
        my $p = $at_vec->copy;
        $p *= $T *= $terminal_space;
        $term->write_vec($text, $p);
        return;
    } elsif ($opts{-justify} eq 'right') {
        my $T = Matrix3::translate(- length($text), 0);
        my $p = $at_vec->copy;
        $p *= $T *= $terminal_space;
        $term->write_vec($text, $p);
        return;
    }

    $term->write_vec($text, $at_vec * $terminal_space);
}

my $inp = Input::new();

package Menu {
    no autovivification;

    use POSIX;
    use FindBin qw($Bin);
    use lib "$Bin";

    use Matrix3 qw($EAST $WEST $SOUTH $NORTH);
    use Utils qw(getters);

    my $VIEW = <<'EOF';
,-------------------------------,
| Menu                        $T|
|-------------------------------|
| $H MENU1                      |
| $M MENU2                      |
| $D MENU3                      |
|-------------------------------|
| Status: $R                    |
'-------------------------------'
EOF
    my @CYCLES = qw(H M D);
    my %NAMES = (
        H => 'MENU1',
        M => 'MENU2',
        D => 'MENU3',
    );

    getters qw(focus pos lastpos geo);

    sub from_xy(
        $x, $y,
    ) {
        my $geo = Geometry3::from_str($VIEW, -centerfy => 1);
        my $pos = Matrix3::Vec::from_xy($x, $y);
        bless {
            focus => undef,
            status => undef,
            geo => $geo,
            pos => $pos,
            lastpos => undef,
        }, __PACKAGE__;
    }

    sub update($self, @events) {
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
            } elsif ($event->payload->code eq 0x0a && exists $self->{focus}) {
                $self->{status} = sprintf "%s selected", $NAMES{$self->{focus}};
            }
        }

    }

    sub render($self, $dt, $term) {
        # ▶ ▷
        if (!defined $self->lastpos) {
            ::render_geometry($self->pos, $self->geo, $term);
            $self->{lastpos} = $self->{pos}->copy;
        } elsif ($self->lastpos ne $self->pos) {
            ::erase_geometry($self->lastpos, $self->geo, '.', $term);
            ::render_geometry($self->pos, $self->geo, $term);
            $self->{lastpos} = $self->{pos}->copy;
        }

        if ($self->focus) {
            ::render_text($self->pos + $self->geo->points->{$self->focus}, ' ▶', $term);
            ::render_text($self->pos + $self->geo->points->{$_}, ' ▷', $term)
                for grep { $_ ne $self->focus } @CYCLES;
        } else {
            ::render_text($self->pos + $self->geo->points->{$_}, ' ▷', $term)
                for @CYCLES;
        }
        if (defined $self->{status}) {
            ::render_text($self->pos + $self->geo->points->{R}, $self->{status}, $term)
        }
        ::render_text($self->pos + $self->geo->points->{T}, POSIX::strftime("%H:%M:%S", localtime), $term,
            -justify => 'right');
    }


}

my $BLANK = '.';
$term->initscr($BLANK);

my $menu = Menu::from_xy(10,10);
$menu->render(1/60, $term);

# # # render_text($pos, '@', $term);
while (1) {
    my @events = $inp->poll(1);
    # last unless @events;
    $menu->update(@events);
    $menu->render(1/60, $term);
}
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
