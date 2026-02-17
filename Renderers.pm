package Renderers::Naive {
    use v5.36;
    use FindBin qw($Bin);
    use Carp;
    use lib "$Bin";
    use integer;

    use Matrix3;
    use Termlib;
    use Utils qw(getters);

    getters qw(terminal_space term blank mapper);
    
    sub new($terminal_space, $mapper, $blank = '.') {
        bless {
            blank => $blank,
            mapper => $mapper,
            term => Termlib::new(),
            terminal_space => $terminal_space,
        }, __PACKAGE__,
    }

    sub initscr($self) {
        $self->term->initscr($self->blank);
        my $mapper = $self->mapper;
        return unless defined $mapper;
        my $style = $mapper->('DEFAULT');
        confess "Invalid material DEFAULT" if !defined $style;
        confess "style must be a hashref" unless ref($style) eq 'HASH';

        my $fg = exists $style->{-fg} ? ($style->{-fg} // -1) : -1;
        my $bg = exists $style->{-bg} ? ($style->{-bg} // -1) : -1;
        my $attrs = exists $style->{-attrs} ? ($style->{-attrs} // -1) : -1;

        my $cols = Termlib::cols() - 1;
        my $rows = Termlib::rows();
        my $line = $self->blank x $cols;
        for my $row (0 .. $rows - 1) {
            $self->term->write_color($line, 0, $row, $fg, $bg, $attrs);
        }
    }

    sub render_geometry($self, $at_vec, $geo) {
        my $coord_mapper = $self->terminal_space * Matrix3::translate($at_vec->@*);
        for my $po ($geo->@*) {
            my ($pos_vec, $value) = $po->@*;
            $self->term->write_vec($value, $pos_vec * $coord_mapper);
        }
    }

    sub erase_geometry($self, $at_vec, $geo, $char) {
        my $coord_mapper = $self->terminal_space * Matrix3::translate($at_vec->@*);
        for my $po ($geo->@*) {
            my ($pos_vec, $value) = $po->@*;
            $self->term->write_vec($char x length($value), $pos_vec * $coord_mapper);
        }
    }

    sub render_style($self, $pos_vec, $length, %opts) {
        $self->render_text($pos_vec, $self->blank x $length, %opts);
    }

    sub _render_quad($self, $pos_vec, $h, $w, %opts) {
        for my $row (0 .. $h - 1) {
            my $row_pos = $pos_vec * Matrix3::translate(0, -$row);
            $self->render_style($row_pos, $w, %opts);
        }
    }

    sub render_quad($self, $pos_vec, $quad) {
        $self->_render_quad($pos_vec, $quad->height, $quad->width,
            $self->mapper($quad->material)->%*);
    }

    sub render_buffer($self, $pos_vec, $buffer) {
        use Term::ANSIColor qw(color);
        my $pos = $pos_vec * $self->terminal_space;
        my ($col0, $row0) = $pos->@*;

        confess "render_buffer expects packstr l4"
            unless $buffer->packstr eq 'l4';

        my $stride = $buffer->stride;
        my $src_w = $buffer->W;
        my $src_h = $buffer->H;
        my $dst_w = Termlib::cols() - 1;
        my $dst_h = Termlib::rows();
        my $pack_template = sprintf("(%s)*", $buffer->packstr);

        $col0 = int($col0);
        $row0 = int($row0);

        my $dst_x0 = $col0 < 0 ? 0 : $col0;
        my $dst_y0 = $row0 < 0 ? 0 : $row0;
        my $dst_x1 = $col0 + $src_w;
        my $dst_y1 = $row0 + $src_h;
        $dst_x1 = $dst_w if $dst_x1 > $dst_w;
        $dst_y1 = $dst_h if $dst_y1 > $dst_h;

        return if $dst_x0 >= $dst_x1 || $dst_y0 >= $dst_y1;

        my $src_x0 = $dst_x0 - $col0;
        my $src_y0 = $dst_y0 - $row0;
        my $visible_w = $dst_x1 - $dst_x0;
        my $visible_h = $dst_y1 - $dst_y0;

        my $copy_bytes = $visible_w * $stride;
        for my $row (0 .. $visible_h - 1) {
            my $src_idx = (($src_y0 + $row) * $src_w + $src_x0) * $stride;
            my $payload_bytes = substr($buffer->{buf}, $src_idx, $copy_bytes);
            my @payload = unpack($pack_template, $payload_bytes);
            my $outstr = "";

            for (my $i = 0; $i < @payload; $i += 4) {
                my ($cp, $fg, $bg, $attrs) = @payload[$i .. $i + 3];
                $outstr .= color(SGR::fg($fg)) if $fg != -1;
                $outstr .= color(SGR::bg($bg)) if $bg != -1;
                $outstr .= color(SGR::attrs($attrs)) // "" if defined $attrs && $attrs != -1;
                $outstr .= chr($cp);
            }
            $outstr .= color('reset');
            $self->term->write($outstr, $dst_x0, $dst_y0 + $row);
        }
    }

    sub render_line($self, $pos_start, $pos_end, $material) {
        my ($x0, $y0) = $pos_start->@*;
        my ($x1, $y1) = $pos_end->@*;
        my %opts = $self->mapper($material)->%*;
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

    sub render_text($self, $at_vec, $text, %opts) {
        $opts{-justify} //= 'left';
        if ($opts{-justify} eq 'center') {
            my $T = Matrix3::translate(- length($text) / 2, 0);
            my $p = $at_vec->copy;
            $p *= $T *= $self->terminal_space;
            $self->term->write_vec($text, $p);
            return;
        } elsif ($opts{-justify} eq 'right') {
            my $T = Matrix3::translate(- length($text), 0);
            my $p = $at_vec->copy;
            $p *= $T *= $self->terminal_space;
            $self->term->write_vec($text, $p);
            return;
        }

        $self->term->write_vec($text, $at_vec * $self->terminal_space);
    }

    sub render_fmt($self, $at_vec, $fmt, @args) {
        $self->render_text($at_vec, sprf($fmt, @args));
    }

    sub flush($self) {
    }
}

package Renderers::DoubleBuffering {
    use v5.36;
    use utf8;
    use Carp;
    use Data::Dumper;
    use Buffer2D;
    use Utils qw(getters);
    use Matrix3 qw($EAST);
    no autovivification;

    getters qw(
        bbuf
        fbuf
        blank
        height
        terminal_space
        width
        packstr
        term
        mapper
    );

    sub new($terminal_space, $H, $W, $mapper, $blank = '.') {
        my $packstr = "l4";
        confess "missing material mapper" unless defined $mapper;
        my $style = $mapper->('DEFAULT');
        confess "Invalid material DEFAULT" if !defined $style;
        confess "style must be a hashref" unless ref($style) eq 'HASH';

        my $fg = exists $style->{-fg} ? ($style->{-fg} // -1) : -1;
        my $bg = exists $style->{-bg} ? ($style->{-bg} // -1) : -1;
        my $attrs = exists $style->{-attrs} ? ($style->{-attrs} // -1) : -1;
        my @default = (ord($blank), $fg, $bg, $attrs);

        my $bbuf = Buffer2D::new($packstr, $H, $W, \@default, -autoclip => 1);
        my $fbuf = Buffer2D::new($packstr, $H, $W, \@default, -autoclip => 1);
        my $self = bless {
            bbuf => $bbuf,
            fbuf => $fbuf,
            blank => $blank,
            height => $H,
            terminal_space => $terminal_space,
            width => $W,
            packstr => $packstr,
            term => Termlib::new(),
            mapper => $mapper,
        }, __PACKAGE__;

        $self;
    }

    sub initscr($self) {
        my $mapper = $self->mapper;
        my $style = $mapper->('DEFAULT');
        confess "Invalid material DEFAULT" if !defined $style;
        confess "style must be a hashref" unless ref($style) eq 'HASH';

        my $fg = exists $style->{-fg} ? ($style->{-fg} // -1) : -1;
        my $bg = exists $style->{-bg} ? ($style->{-bg} // -1) : -1;
        my $attrs = exists $style->{-attrs} ? ($style->{-attrs} // -1) : -1;

        my $cols = $self->width;
        my $rows = $self->height;
        my $line = $self->blank x $cols;
        for my $row (0 .. $rows - 1) {
            $self->term->write_color($line, 0, $row, $fg, $bg, $attrs);
        }
    }

    sub render_geometry($self, $pos_vec, $geo) {
        for my $po ($geo->@*) {
            my ($pos, $text, $fg, $bg, $attrs) = $po->@*;
            $self->render_text($pos + $pos_vec, $text,
                -fg     => $fg,
                -bg     => $bg,
                -attrs => $attrs,
            );
        }
    }

    sub erase_geometry($self, $pos_vec, $geo, $char = undef) {
        my $blank = $char // $self->blank;
        for my $po ($geo->@*) {
            my ($pos, $text, $fg, $bg, $attrs) = $po->@*;
            $self->render_text($pos + $pos_vec, $blank x length($text));
        }
    }

    sub render_text($self, $pos_vec, $text, %opts) {
        no autovivification;
        # say "render_text $text";
        # $opts{$_} //= -1
        #     for qw(-fg -bg -attrs);
        $opts{-justify} //= 'left';


        my $fg = $opts{-fg};
        my $bg = $opts{-bg};
        my $attrs = $opts{-attrs};

        my $pos = $pos_vec * $self->terminal_space;
        if ($opts{-justify} eq 'right') {
            $pos *= Matrix3::translate(-length($text), 0);
        } elsif ($opts{-justify} eq 'center') {
            $pos *= Matrix3::translate(-length($text)/2, 0);
        }

        my @unpacked;
        for my $codepo (split //u, $text) {
            push @unpacked, [ord($codepo), $fg, $bg, $attrs];
        }

        # say "Prerendering <$text>";
        $self->bbuf->update_multi($pos->@*, @unpacked);
    }

    sub render_style($self, $pos_vec, $length, %opts) {
        $self->render_text($pos_vec, $self->blank x $length, %opts);
    }

    sub _render_quad($self, $pos_vec, $h, $w, %opts) {
        for my $row (0 .. $h - 1) {
            my $row_pos = $pos_vec * Matrix3::translate(0, -$row);
            $self->render_style($row_pos, $w, %opts);
        }
    }

    sub render_quad($self, $pos_vec, $quad) {
        $self->_render_quad($pos_vec, $quad->height, $quad->width,
            $self->mapper->style($quad->material)->%*);
    }

    sub render_buffer($self, $pos_vec, $buffer) {
        my $pos = $pos_vec * $self->terminal_space;
        my ($col0, $row0) = $pos->@*;

        confess "render_buffer expects packstr l4"
            unless $buffer->packstr eq 'l4';
        confess "render_buffer expects packstr l4"
            unless $self->bbuf->packstr eq 'l4';

        my $stride = $buffer->stride;
        my $src_w = $buffer->W;
        my $src_h = $buffer->H;
        my $dst_w = $self->bbuf->W;
        my $dst_h = $self->bbuf->H;

        $col0 = int($col0);
        $row0 = int($row0);

        my $dst_x0 = $col0 < 0 ? 0 : $col0;
        my $dst_y0 = $row0 < 0 ? 0 : $row0;
        my $dst_x1 = $col0 + $src_w;
        my $dst_y1 = $row0 + $src_h;
        $dst_x1 = $dst_w if $dst_x1 > $dst_w;
        $dst_y1 = $dst_h if $dst_y1 > $dst_h;

        return if $dst_x0 >= $dst_x1 || $dst_y0 >= $dst_y1;

        my $src_x0 = $dst_x0 - $col0;
        my $src_y0 = $dst_y0 - $row0;
        my $visible_w = $dst_x1 - $dst_x0;
        my $visible_h = $dst_y1 - $dst_y0;

        my $copy_bytes = $visible_w * $stride;
        for my $row (0 .. $visible_h - 1) {
            my $src_idx = (($src_y0 + $row) * $src_w + $src_x0) * $stride;
            my $dst_idx = (($dst_y0 + $row) * $dst_w + $dst_x0) * $stride;
            substr($self->bbuf->{buf}, $dst_idx, $copy_bytes)
                = substr($buffer->{buf}, $src_idx, $copy_bytes);
            $self->bbuf->{_updated_rows}->{ $dst_y0 + $row }++;
        }
    }

    sub render_line($self, $pos_start, $pos_end, $material) {
        my ($x0, $y0) = $pos_start->@*;
        my ($x1, $y1) = $pos_end->@*;
        my %opts = $self->mapper->style($material)->%*;
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

    sub render_fmt($self, $pos_vec, $fmt, @args) {
        $self->render_text($pos_vec, sprintf($fmt, @args));
    }

    sub flush($self) {
        use Term::ANSIColor qw(color);
        no autovivification;

        my @updates = $self->bbuf->diff($self->fbuf);

        my %terminal_state = (
            fg => undef,
            bg => undef,
            attrs => undef,
        );

        for my $update (@updates) {
            my $payload = $update->{payload};
            my $step = int($update->{payload}->@* / $update->{size});
            my $outstr = "";

            my $terminal_state = undef;
            Utils::Array::for_batch {
                my ($cp, $fg, $bg, $attrs) = @_;

                if (!defined $terminal_state
                    || (   $fg    != $terminal_state->{fg}
                        || $bg    != $terminal_state->{bg}
                        || $attrs != $terminal_state->{attrs})) {
                    $outstr .= color(SGR::fg($fg)) if $fg != -1;
                    $outstr .= color(SGR::bg($bg)) if $bg != -1;
                    $outstr .= color(SGR::attrs($attrs)) // "" if defined $attrs && $attrs != -1;
                    $terminal_state = {
                        fg => $fg,
                        bg => $bg,
                        attrs => $attrs,
                    };
                }
                $outstr .= chr($cp);
            } $step, $payload;
            $outstr .= color('reset');
            $terminal_state = undef;
            $self->term->write($outstr, $update->{col}, $update->{row});
        }

        $self->fbuf->sync($self->bbuf);
    }

    sub reset($self) {
        # update the front buffer, take advantage of perl string's CoW
        $self->{fbuf} = $self->bbuf;
    }

    sub _pack($self, $glyph, $fg = -1 , $bg = -1, $attrs = -1) {
        confess "null glyph" if !defined $glyph;
        pack($self->packstr, ord($glyph), $fg, $bg, $attrs);
    }

}


1;

__END__

=head1 NAME

Renderers

=head1 SYNOPSIS

    use Renderers;
    my $renderer = Renderers::DoubleBuffering::new($T, $H, $W, $mapper, ' ');
    $renderer->initscr;
    $renderer->render_text($pos, "Hello");
    $renderer->flush;

=head1 DESCRIPTION

Renderers provides two renderer implementations used by the TUI:

Renderers::Naive writes directly to the terminal for every draw call.
Renderers::DoubleBuffering writes into a back buffer and flushes the
diff to the terminal.

Both implement a shared API for text, quads, geometry, lines, and
buffer blits.

=head1 COMMON METHODS

=over 4

=item render_text($pos_vec, $text, %opts)

Renders text at a position. Supports C<-fg>, C<-bg>, C<-attrs> and
justification via C<-justify>.

=item render_quad($pos_vec, $quad)

Renders a rectangle from a Quad material.

=item render_geometry($pos_vec, $geo)

Renders a Geometry3 payload at an offset.

=item render_line($pos_start, $pos_end, $material)

Renders a line with the given material.

=item render_buffer($pos_vec, $buffer)

Blits a Buffer2D onto the destination (clipped).

=item initscr

Clears the terminal and fills it with the default background.

=item flush

No-op for Naive; emits diffs for DoubleBuffering.

=back
