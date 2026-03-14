package Surface;

use v5.36;
use utf8;
use Carp;
use FindBin qw($Bin);
use lib "$Bin";

use Buffer2D;
use MaterialMapper;
use Matrix3;
use Utils qw(getters);

getters qw(
    buffer
    height
    width
    blank
    material
);

sub new($H, $W, %opts) {
    confess "missing height" unless defined $H;
    confess "missing width" unless defined $W;
    my $defaults = $opts{-defaults} // [-1, -1, -1, -1];
    confess "defaults must be arrayref"
        unless ref($defaults) eq 'ARRAY';
    confess "defaults must have 4 elements"
        unless $defaults->@* == 4;

    my $autoclip = exists $opts{-autoclip} ? $opts{-autoclip} : 1;
    my $blank = $opts{-blank} // ' ';
    my $material = $opts{-material};
    confess "missing material" unless defined $material;
    confess "material must support style()"
        unless ref($material) && $material->can('style');

    my $buffer = Buffer2D::new("l4", $H, $W, $defaults, -autoclip => $autoclip);
    bless {
        buffer => $buffer,
        height => $H,
        width => $W,
        blank => $blank,
        material => $material,
    }, __PACKAGE__;
}

sub _coords($pos_vec) {
    _assert_vec($pos_vec);
    my ($x, $y) = $pos_vec->@*;
    ($x, -$y);
}

sub _style_for($self, $material) {
    $self->{material}->style($material);
}

sub _assert_vec($vec) {
    my $type = ref($vec);
    $type =~ s/^.*::// if $type;
    confess "invalid position" unless defined $type && $type eq 'Vec';
}

sub _render_style($self, $pos_vec, $length, %opts) {
    $self->render_text($pos_vec, $self->{blank} x $length, %opts);
}

sub render_text($self, $pos_vec, $text, %opts) {
    _assert_vec($pos_vec);
    $opts{-justify} //= 'left';
    my ($col, $row) = _coords($pos_vec);
    if ($opts{-justify} eq 'right') {
        $col -= length($text);
    } elsif ($opts{-justify} eq 'center') {
        $col -= int(length($text) / 2);
    }

    my $fg = $opts{-fg};
    my $bg = $opts{-bg};
    my $attrs = $opts{-attrs};

    my @unpacked;
    for my $codepo (split //u, $text) {
        push @unpacked, [ord($codepo), $fg, $bg, $attrs];
    }
    $self->{buffer}->update_multi($col, $row, @unpacked);
}

sub render_line($self, $pos_start, $pos_end, $material) {
    _assert_vec($pos_start);
    _assert_vec($pos_end);
    my ($x0, $y0) = ref($pos_start) eq 'ARRAY' ? $pos_start->@* : $pos_start->@*;
    my ($x1, $y1) = ref($pos_end) eq 'ARRAY' ? $pos_end->@* : $pos_end->@*;
    my %opts = $self->_style_for($material)->%*;
    my $glyph = $self->{blank};

    my $dx = abs($x1 - $x0);
    my $sx = $x0 < $x1 ? 1 : -1;
    my $dy = -abs($y1 - $y0);
    my $sy = $y0 < $y1 ? 1 : -1;
    my $err = $dx + $dy;

    while (1) {
        $self->render_text(Matrix3::Vec::from_xy($x0, $y0), $glyph, %opts);
        last if $x0 == $x1 && $y0 == $y1;
        my $e2 = 2 * $err;
        if ($e2 >= $dy) {
            $err += $dy;
            $x0 += $sx;
        }
        if ($e2 <= $dx) {
            $err += $dx;
            $y0 += $sy;
        }
    }
}

sub render_quad($self, $pos_vec, $quad) {
    _assert_vec($pos_vec);
    my $style = $self->_style_for($quad->material);
    for my $row (0 .. $quad->height - 1) {
        my $row_pos = $pos_vec * Matrix3::translate(0, -$row);
        $self->_render_style($row_pos, $quad->width, $style->%*);
    }
}

sub render_geometry($self, $pos_vec, $geo) {
    _assert_vec($pos_vec);
    for my $po ($geo->@*) {
        my ($pos, $text, $fg, $bg, $attrs) = $po->@*;
        $self->render_text($pos + $pos_vec, $text,
            -fg => $fg,
            -bg => $bg,
            -attrs => $attrs,
        );
    }
}

1;

__END__

=head1 NAME

Surface

=head1 SYNOPSIS

    use Surface;
    use Matrix3;
    use Quad;
    use MaterialMapper;

    my $mat = MaterialMapper::from_callback(sub ($material) {
        return { -bg => 0x303030 } if $material eq 'BG';
        return { -fg => 0xffffff } if $material eq 'FG';
    });

    my $surface = Surface::new(10, 20, -material => $mat);

    $surface->render_text(Matrix3::Vec::from_xy(1, 0), "Hello", -fg => 0xffffff);
    $surface->render_line(Matrix3::Vec::from_xy(0, 0), Matrix3::Vec::from_xy(5, -2), 'BG');
    $surface->render_quad(Matrix3::Vec::from_xy(0, 0), Quad::from_wh(4, 2, 'BG'));

=head1 DESCRIPTION

Surface is an offscreen, compositing buffer built on top of Buffer2D. It
implements a renderer-like API that writes into an internal buffer so multiple
layers can be composed before being blitted elsewhere.

Coordinates use the same convention as other renderers in this codebase:
X increases to the right, Y increases upward. The top-left corner of the
surface is (0, 0); rows extend downward with negative Y.

=head1 METHODS

=over 4

=item new($height, $width, %opts)

Creates a new Surface.

Options:

=over 4

=item * C<-material>

L<MaterialMapper> instance that maps a material name to a L<TerminalStyle>
containing C<-fg>, C<-bg>, and/or C<-attrs>.

=item * C<-blank>

Glyph used for filled styles (default: space).

=item * C<-defaults>

Arrayref of 4 integers for Buffer2D defaults (default: C<-1, -1, -1, -1>).

=item * C<-autoclip>

Enable bounds clipping (default: 1).

=back

=item render_text($pos_vec, $text, %opts)

Writes text at the given position. Supports C<-fg>, C<-bg>, C<-attrs>, and
C<-justify> (left/center/right).

=item render_line($pos_start, $pos_end, $material)

Rasterizes a line and fills it using the style for C<$material>.

=item render_quad($pos_vec, $quad)

Fills a rectangle using the quad's material.

=item render_geometry($pos_vec, $geo)

Renders a Geometry3 object. Each geometry entry may include fg/bg/attrs.

=item buffer

Returns the internal Buffer2D instance.

=back

=cut
