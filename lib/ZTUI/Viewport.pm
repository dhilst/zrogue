package ZTUI::Viewport;
use v5.36;
use utf8;
use integer;

use ZTUI::Utils qw(getters);
use ZTUI::Matrix3;

getters qw(
    h w
    center
    topleft
    topright
    bottomleft
    bottomright 
);

# $pos_vec is expected to be ZTUI::Matrix3::Vec
# $h and $w are integers
sub from_pos_hw($pos_vec, $h, $w) {
    my $center = $pos_vec * ZTUI::Matrix3::translate(($w - 1) / 2, -$h / 2);
    my $topleft = $pos_vec;
    my $topright = $pos_vec * ZTUI::Matrix3::translate($w-1, 0);
    my $bottomleft = $pos_vec * ZTUI::Matrix3::translate(0, -$h+1);
    my $bottomright = $pos_vec * ZTUI::Matrix3::translate($w-1, -$h+1);
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

=head1 NAME

Viewport

=head1 SYNOPSIS

    use ZTUI::Viewport;
    my $vp = ZTUI::Viewport::from_pos_hw($pos, $h, $w);
    my $center = $vp->center;

=head1 DESCRIPTION

Viewport computes commonly used positions (center and corners) from a
top-left position and dimensions. It uses the same coordinate system as
the renderers where Y increases upward.

=head1 METHODS

=over 4

=item from_pos_hw($pos_vec, $h, $w)

Constructs a Viewport from a top-left position and size.

=item move($matrix)

Transforms all stored points by the given matrix.

=back

=head1 NOTES

Y grows upward, so bottom positions have negative Y. This keeps the
world space convention consistent with rendering.

