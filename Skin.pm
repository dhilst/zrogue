package Skin;

use v5.36;
use utf8;
use Carp;

use lib ".";
use Matrix3;
use Quad;
use Surface;

sub _bounds($geo) {
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
    confess "empty geometry" unless defined $minx;
    ($minx, $maxx, $miny, $maxy);
}

sub from_geometry($geo, %opts) {
    confess "missing geometry" unless defined $geo;
    my $material = $opts{-material};
    confess "missing material mapper" unless defined $material;
    confess "material must support style()"
        unless ref($material) && $material->can('style');
    my $bg = $opts{-bg};
    confess "missing bg material" unless defined $bg;
    my $shadow = $opts{-shadow};
    my $blank = $opts{-blank} // ' ';
    my $autoclip = exists $opts{-autoclip} ? $opts{-autoclip} : 1;

    my ($minx, $maxx, $miny, $maxy) = _bounds($geo);
    my $bg_w = $maxx - $minx + 1;
    my $bg_h = $maxy - $miny + 1;
    my $extra = defined $shadow ? 1 : 0;
    my $surface_w = $bg_w + $extra;
    my $surface_h = $bg_h + $extra;

    my $defaults = $opts{-defaults};
    if (!defined $defaults) {
        my $style = $material->style('DEFAULT');
        my $fg = exists $style->{-fg} ? ($style->{-fg} // -1) : -1;
        my $bgc = exists $style->{-bg} ? ($style->{-bg} // -1) : -1;
        my $attrs = exists $style->{-attrs} ? ($style->{-attrs} // -1) : -1;
        $defaults = [ord($blank), $fg, $bgc, $attrs];
    }

    my $surface = Surface::new($surface_h, $surface_w,
        -material => $material,
        -defaults => $defaults,
        -blank => $blank,
        -autoclip => $autoclip);

    my $geo_offset = Matrix3::Vec::from_xy(-$minx, -$maxy);
    my $bg_quad = Quad::from_wh($bg_w, $bg_h, $bg);
    $surface->render_quad(Matrix3::Vec::from_xy(0, 0), $bg_quad);

    if (defined $shadow) {
        $surface->render_line(
            Matrix3::Vec::from_xy($bg_w, -1),
            Matrix3::Vec::from_xy($bg_w, -$bg_h),
            $shadow,
        );
        if ($bg_w > 1) {
            $surface->render_line(
                Matrix3::Vec::from_xy(1, -$bg_h),
                Matrix3::Vec::from_xy($bg_w - 1, -$bg_h),
                $shadow,
            );
        }
    }

    $surface->render_geometry($geo_offset, $geo);
    return $surface;
}

1;

__END__

=head1 NAME

Skin

=head1 SYNOPSIS

    use Skin;
    my $surface = Skin::from_geometry($geo,
        -material => $mat,
        -bg => 'MENU_BG',
        -shadow => 'SHADOW_BG',
    );

=head1 DESCRIPTION

Skin builds a Surface from a Geometry3 payload. It fills a background
quad, optionally draws a shadow on the right and bottom edges, and then
renders the geometry on top.

=head1 FUNCTIONS

=over 4

=item from_geometry($geo, %opts)

Creates and returns a Surface. Options:

- C<-material> MaterialMapper instance (required)
- C<-bg> background material name (required)
- C<-shadow> shadow material name (optional)
- C<-defaults> Buffer2D defaults arrayref (optional)
- C<-blank> glyph used for fills (optional)
- C<-autoclip> Surface autoclip flag (optional)

=back

