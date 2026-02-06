package Viewport;
use v5.36;
use utf8;
use integer;

use lib ".";
use Utils qw(getters);
use Matrix3;

getters qw(
    h w
    center
    topleft
    topright
    bottomleft
    bottomright 
);

# $pos_vec is expected to be Matrix3::Vec
# $h and $w are integers
sub from_pos_hw($pos_vec, $h, $w) {
    my $center = $pos_vec * Matrix3::translate(($w - 1) / 2, -$h / 2);
    my $topleft = $pos_vec;
    my $topright = $pos_vec * Matrix3::translate($w-1, 0);
    my $bottomleft = $pos_vec * Matrix3::translate(0, -$h+1);
    my $bottomright = $pos_vec * Matrix3::translate($w-1, -$h+1);
    my $self = bless {
        h => $h,
        w => $w,
        center => $center,
        topleft => $topleft,
        topright => $topright,
        bottomleft => $bottomleft,
        bottomright => $bottomright,
    }, __PACKAGE__;
}

sub move($self, $to_matrix) {
    for my $key (qw(center topleft topright bottomleft bottomright)) {
        $self->{$key} *= $to_matrix;
    }
}

1;

__END__

=head1 SYNOPSIS

Viewport allow you to get center, and corner positions from an initial position $pos,
and dimmesions H x W. Then the user can use the following methods to get each position

=head1 NOTES

1. The Y grows UP, so bottomleft and bottomright are in -H negative values. This means
   that the second row is -1 not 1. This is to keep Y grows upwards convetion.


