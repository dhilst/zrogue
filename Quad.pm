package Quad;

use v5.36;
use utf8;
use Carp;

use lib ".";
use Utils qw(getters);
use Matrix3;

use overload
    '""' => \&to_string;

getters qw(
    material
    topleft
    topright
    bottomleft
    bottomright
    center
    width
    height
);

sub to_string($self, @ignored) {
    sprintf "Quad(%s, %s, %s)",
        $self->topleft,
        $self->bottomright,
        $self->material // "undef";
}

sub from_wh($width, $height, $material = undef) {
    confess "missing width" unless defined $width;
    confess "missing height" unless defined $height;

    my $topleft = Matrix3::Vec::from_xy(0, 0);
    my $topright = Matrix3::Vec::from_xy($width, 0);
    my $bottomleft = Matrix3::Vec::from_xy(0, -$height);
    my $bottomright = Matrix3::Vec::from_xy($width, -$height);
    my $center = Matrix3::Vec::from_xy($width / 2, -$height / 2);

    bless {
        topleft => $topleft,
        topright => $topright,
        bottomleft => $bottomleft,
        bottomright => $bottomright,
        center => $center,
        width => $width,
        height => $height,
        material => $material,
    }, __PACKAGE__;
}

1;

__END__

=head1 NAME

Quad

=head1 SYNOPSIS

use Quad;
use Matrix3;

my $topleft = Matrix3::Vec::from_xy(0, 0);
my $quad = Quad::from_wh(10, 5);

=head1 DESCRIPTION

Quad defines a rectangular region using width and height. The accessors provide
the corners and center of a quad whose top-left is at C<(0, 0)>.

=head1 METHODS

=over 4

=item from_wh($width, $height)

Constructs a Quad from width and height. Width extends to the right, height
extends downward (negative Y).

=item topleft, bottomright

Accessors for the original corner points.

=item topleft, topright, bottomleft, bottomright

Accessors for each corner of the rectangle.

=item center

Accessor for the center point.

=item width, height

Accessors for the rectangle dimensions derived from corners.

=back
