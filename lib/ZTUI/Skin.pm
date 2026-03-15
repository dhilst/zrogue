package ZTUI::Skin;

use v5.36;
use utf8;
use Carp;

use ZTUI::Matrix3;
use ZTUI::Quad;
use ZTUI::Surface;

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

sub layout($geo) {
    confess "missing geometry" unless defined $geo;
    my ($minx, $maxx, $miny, $maxy) = _bounds($geo);
    my $width = $maxx - $minx + 1;
    my $height = $maxy - $miny + 1;
    return {
        minx => $minx,
        maxx => $maxx,
        miny => $miny,
        maxy => $maxy,
        width => $width,
        height => $height,
        topleft => ZTUI::Matrix3::Vec::from_xy($minx, $maxy),
        geo_offset => ZTUI::Matrix3::Vec::from_xy(-$minx, -$maxy),
    };
}

sub from_geometry($geo, %opts) {
    confess "missing geometry" unless defined $geo;
    my $mapper = $opts{-mapper};
    confess "missing material mapper" unless defined $mapper;
    confess "mapper must support style()"
        unless ref($mapper) && $mapper->can('style');
    my $bg = $opts{-bg};
    confess "missing bg material" unless defined $bg;
    my $shadow = $opts{-shadow};
    my $clear = $opts{-clear} // 'DEFAULT_BG';
    my $blank = $opts{-blank} // ' ';
    my $autoclip = exists $opts{-autoclip} ? $opts{-autoclip} : 1;

    my $layout = layout($geo);
    my ($minx, $maxx, $miny, $maxy) = @{$layout}{qw(minx maxx miny maxy)};
    my $bg_w = $layout->{width};
    my $bg_h = $layout->{height};
    my $extra = defined $shadow ? 1 : 0;
    my $surface_w = $bg_w + $extra;
    my $surface_h = $bg_h + $extra;

    my $defaults = $opts{-defaults};
    if (!defined $defaults) {
        my $style = $mapper->style('DEFAULT');
        my $fg = exists $style->{-fg} ? ($style->{-fg} // -1) : -1;
        my $bgc = exists $style->{-bg} ? ($style->{-bg} // -1) : -1;
        my $attrs = exists $style->{-attrs} ? ($style->{-attrs} // -1) : -1;
        $defaults = [ord($blank), $fg, $bgc, $attrs];
    }

    my $surface = ZTUI::Surface::new($surface_h, $surface_w,
        -material => $mapper,
        -defaults => $defaults,
        -blank => $blank,
        -autoclip => $autoclip);
    my $clear_surface = ZTUI::Surface::new($surface_h, $surface_w,
        -material => $mapper,
        -defaults => $defaults,
        -blank => $blank,
        -autoclip => $autoclip);

    my $geo_offset = $layout->{geo_offset};
    my $bg_quad = ZTUI::Quad::from_wh($bg_w, $bg_h, $bg);
    $surface->render_quad(ZTUI::Matrix3::Vec::from_xy(0, 0), $bg_quad);

    if (defined $shadow) {
        $surface->render_line(
            ZTUI::Matrix3::Vec::from_xy($bg_w, -1),
            ZTUI::Matrix3::Vec::from_xy($bg_w, -$bg_h),
            $shadow,
        );
        if ($bg_w > 1) {
            $surface->render_line(
                ZTUI::Matrix3::Vec::from_xy(1, -$bg_h),
                ZTUI::Matrix3::Vec::from_xy($bg_w - 1, -$bg_h),
                $shadow,
            );
        }
    }

    $surface->render_geometry($geo_offset, $geo);
    my $clear_quad = ZTUI::Quad::from_wh($surface_w, $surface_h, $clear);
    $clear_surface->render_quad(ZTUI::Matrix3::Vec::from_xy(0, 0), $clear_quad);

    return wantarray ? ($surface, $clear_surface) : $surface;
}

1;

__END__

=head1 NAME

Skin

=head1 SYNOPSIS

    use ZTUI::Skin;
    my $surface = ZTUI::Skin::from_geometry($geo,
        -mapper => $mat,
        -bg => 'MENU_BG',
        -shadow => 'SHADOW_BG',
    );

=head1 DESCRIPTION

Skin builds a Surface from a Geometry3 payload. It fills a background
quad, optionally draws a shadow on the right and bottom edges, and then
renders the geometry on top. In list context it also returns a matching
clean surface for erase operations.

=head1 FUNCTIONS

=over 4

=item from_geometry($geo, %opts)

Creates and returns a Surface. Options:

- C<-mapper> MaterialMapper instance (required)
- C<-bg> background material name (required)
- C<-shadow> shadow material name (optional)
- C<-clear> clear material name (default: C<DEFAULT_BG>)
- C<-defaults> Buffer2D defaults arrayref (optional)
- C<-blank> glyph used for fills (optional)
- C<-autoclip> Surface autoclip flag (optional)

=back

=item layout($geo)

Returns a hashref containing bounds, dimensions, and useful offsets:
C<minx>, C<maxx>, C<miny>, C<maxy>, C<width>, C<height>, C<topleft>,
and C<geo_offset>.
