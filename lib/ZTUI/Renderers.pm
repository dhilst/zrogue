package ZTUI::Renderers::Naive {
    use v5.36;
    use FindBin qw($Bin);
    use Carp;
    use lib "$Bin";

    use ZTUI::Matrix3;
    use ZTUI::Termlib;
    use ZTUI::Utils qw(getters);

    getters qw(terminal_space term blank mapper);

    sub _quantize_xy($pos_vec) {
        my ($col, $row) = $pos_vec->@*;
        return (int($col), int($row));
    }

    sub _write_quantized($self, $text, $pos_vec) {
        my ($col, $row) = _quantize_xy($pos_vec);
        $self->term->write($text, $col, $row);
    }

    sub _style_fields($style) {
        confess "missing style" unless defined $style;
        if (ref($style) eq 'ZTUI::TerminalStyle') {
            return (
                defined($style->fg) ? $style->fg : -1,
                defined($style->bg) ? $style->bg : -1,
                defined($style->attrs) ? $style->attrs : -1,
            );
        }

        confess "style must support fg/bg/attrs or be a hashref"
            unless ref($style) eq 'HASH';
        return (
            exists $style->{-fg} ? ($style->{-fg} // -1) : -1,
            exists $style->{-bg} ? ($style->{-bg} // -1) : -1,
            exists $style->{-attrs} ? ($style->{-attrs} // -1) : -1,
        );
    }
    
    sub new($terminal_space, $mapper, $blank = '.') {
        bless {
            blank => $blank,
            mapper => $mapper,
            term => ZTUI::Termlib::new(),
            terminal_space => $terminal_space,
        }, __PACKAGE__,
    }

    sub initscr($self) {
        $self->term->initscr($self->blank);
        my $mapper = $self->mapper;
        return unless defined $mapper;
        my $style = $mapper->('DEFAULT');
        confess "Invalid material DEFAULT" if !defined $style;
        my ($fg, $bg, $attrs) = _style_fields($style);

        my $cols = ZTUI::Termlib::cols() - 1;
        my $rows = ZTUI::Termlib::rows();
        my $line = $self->blank x $cols;
        for my $row (0 .. $rows - 1) {
            $self->term->write_color($line, 0, $row, $fg, $bg, $attrs);
        }
    }

    sub render_geometry($self, $at_vec, $geo) {
        my $coord_mapper = $self->terminal_space * ZTUI::Matrix3::translate($at_vec->@*);
        for my $po ($geo->@*) {
            my ($pos_vec, $value) = $po->@*;
            $self->_write_quantized($value, $pos_vec * $coord_mapper);
        }
    }

    sub erase_geometry($self, $at_vec, $geo, $char) {
        my $coord_mapper = $self->terminal_space * ZTUI::Matrix3::translate($at_vec->@*);
        for my $po ($geo->@*) {
            my ($pos_vec, $value) = $po->@*;
            $self->_write_quantized($char x length($value), $pos_vec * $coord_mapper);
        }
    }

    sub render_style($self, $pos_vec, $length, %opts) {
        $self->render_text($pos_vec, $self->blank x $length, %opts);
    }

    sub _render_quad($self, $pos_vec, $h, $w, %opts) {
        for my $row (0 .. $h - 1) {
            my $row_pos = $pos_vec * ZTUI::Matrix3::translate(0, -$row);
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
        my $dst_w = ZTUI::Termlib::cols() - 1;
        my $dst_h = ZTUI::Termlib::rows();
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
                $outstr .= color(ZTUI::SGR::fg($fg)) if $fg != -1;
                $outstr .= color(ZTUI::SGR::bg($bg)) if $bg != -1;
                $outstr .= color(ZTUI::SGR::attrs($attrs)) // "" if defined $attrs && $attrs != -1;
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
            $self->render_text(ZTUI::Matrix3::Vec::from_xy($x0, $y0), $glyph, %opts);
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
            my $T = ZTUI::Matrix3::translate(- length($text) / 2, 0);
            my $p = $at_vec->copy;
            $p *= $T *= $self->terminal_space;
            $self->_write_quantized($text, $p);
            return;
        } elsif ($opts{-justify} eq 'right') {
            my $T = ZTUI::Matrix3::translate(- length($text), 0);
            my $p = $at_vec->copy;
            $p *= $T *= $self->terminal_space;
            $self->_write_quantized($text, $p);
            return;
        }

        $self->_write_quantized($text, $at_vec * $self->terminal_space);
    }

    sub render_fmt($self, $at_vec, $fmt, @args) {
        $self->render_text($at_vec, sprf($fmt, @args));
    }

    sub flush($self) {
    }
}

package ZTUI::Renderers::DoubleBuffering {
    use v5.36;
    use utf8;
    use Carp;
    use Data::Dumper;
    use ZTUI::Buffer2D;
    use ZTUI::Utils qw(getters);
    use ZTUI::Matrix3 qw($EAST);
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
        theme
        static_cache
        frame_cache
        frame_stamp
    );

    sub _quantize_xy($pos_vec) {
        my ($col, $row) = $pos_vec->@*;
        return (int($col), int($row));
    }

    sub _style_fields($style) {
        confess "missing style" unless defined $style;
        if (ref($style) eq 'ZTUI::TerminalStyle') {
            return (
                defined($style->fg) ? $style->fg : -1,
                defined($style->bg) ? $style->bg : -1,
                defined($style->attrs) ? $style->attrs : -1,
            );
        }

        confess "style must support fg/bg/attrs or be a hashref"
            unless ref($style) eq 'HASH';
        return (
            exists $style->{-fg} ? ($style->{-fg} // -1) : -1,
            exists $style->{-bg} ? ($style->{-bg} // -1) : -1,
            exists $style->{-attrs} ? ($style->{-attrs} // -1) : -1,
        );
    }

    sub _build_resolver($resolver) {
        return {
            theme => $resolver,
            mapper => undef,
        } if defined($resolver) && ref($resolver) && $resolver->can('border');

        return {
            theme => undef,
            mapper => $resolver,
        };
    }

    sub _default_material($self) {
        return 'DEFAULT' if defined $self->{theme};
        return undef;
    }

    sub _style_from_opts_or_material($self, $x, $y, %opts) {
        return (
            $opts{-fg},
            $opts{-bg},
            $opts{-attrs},
        ) if exists($opts{-fg}) || exists($opts{-bg}) || exists($opts{-attrs});

        my $material = exists($opts{-material}) ? $opts{-material} : $self->_default_material;
        my $style = $self->_resolve_material_style($material, $x, $y);
        return _style_fields($style);
    }

    sub _resolve_material_style($self, $material, $x = 0, $y = 0) {
        return $self->mapper->style($material) unless defined $self->{theme};

        my $cache_class = $self->theme->material_cache_class($material);
        my $cache_key = $self->theme->material_cache_key($self->{frame_stamp}, $x, $y, $material);
        my $cache = $cache_class eq 'STATIC_UNIFORM'
            ? $self->{static_cache}{material}
            : $self->{frame_cache}{material};

        return $cache->{$cache_key} if exists $cache->{$cache_key};
        my $style = $self->theme->style($material,
            x => $x,
            y => $y,
            dt => $self->{frame_stamp},
            renderer_width => $self->width,
            renderer_height => $self->height,
        );
        $cache->{$cache_key} = $style;
        return $style;
    }

    sub _resolve_border_style($self, $border_material, $x = 0, $y = 0, $edge = 'CENTER') {
        confess "render_border requires theme with border support"
            unless defined $self->{theme};

        my $cache_class = $self->theme->border_cache_class($border_material);
        my $cache_key = $self->theme->border_cache_key($self->{frame_stamp}, $x, $y, $border_material, $edge);
        my $cache = $cache_class eq 'STATIC_UNIFORM'
            ? $self->{static_cache}{border}
            : $self->{frame_cache}{border};

        return $cache->{$cache_key} if exists $cache->{$cache_key};
        my $style = $self->theme->border($border_material,
            x => $x,
            y => $y,
            edge => $edge,
            dt => $self->{frame_stamp},
            renderer_width => $self->width,
            renderer_height => $self->height,
        );
        $cache->{$cache_key} = $style;
        return $style;
    }

    sub new($terminal_space, $H, $W, $resolver, $blank = '.') {
        my $packstr = "l4";
        confess "missing material mapper or theme" unless defined $resolver;
        my $resolved = _build_resolver($resolver);
        my $style = defined($resolved->{theme})
            ? $resolved->{theme}->style('DEFAULT')
            : $resolved->{mapper}->('DEFAULT');
        confess "Invalid material DEFAULT" if !defined $style;
        my ($fg, $bg, $attrs) = _style_fields($style);
        my @default = (ord($blank), $fg, $bg, $attrs);

        my $bbuf = ZTUI::Buffer2D::new($packstr, $H, $W, \@default, -autoclip => 1);
        my $fbuf = ZTUI::Buffer2D::new($packstr, $H, $W, \@default, -autoclip => 1);
        my $self = bless {
            bbuf => $bbuf,
            fbuf => $fbuf,
            blank => $blank,
            height => $H,
            terminal_space => $terminal_space,
            width => $W,
            packstr => $packstr,
            term => ZTUI::Termlib::new(),
            mapper => $resolved->{mapper},
            theme => $resolved->{theme},
            static_cache => { material => {}, border => {} },
            frame_cache => { material => {}, border => {} },
            frame_stamp => 0,
        }, __PACKAGE__;

        $self;
    }

    sub initscr($self) {
        my $style = defined($self->{theme})
            ? $self->{theme}->style('DEFAULT')
            : $self->mapper->('DEFAULT');
        confess "Invalid material DEFAULT" if !defined $style;
        my ($fg, $bg, $attrs) = _style_fields($style);

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


        my $pos = $pos_vec * $self->terminal_space;
        if ($opts{-justify} eq 'right') {
            $pos *= ZTUI::Matrix3::translate(-length($text), 0);
        } elsif ($opts{-justify} eq 'center') {
            $pos *= ZTUI::Matrix3::translate(-length($text)/2, 0);
        }
        my ($col, $row) = _quantize_xy($pos);
        my ($fg, $bg, $attrs) = $self->_style_from_opts_or_material($col, $row, %opts);

        my @unpacked;
        for my $codepo (split //u, $text) {
            push @unpacked, [ord($codepo), $fg, $bg, $attrs];
        }

        # say "Prerendering <$text>";
        $self->bbuf->update_multi($col, $row, @unpacked);
    }

    sub render_style($self, $pos_vec, $length, %opts) {
        $self->render_text($pos_vec, $self->blank x $length, %opts);
    }

    sub render_rect($self, $pos_vec, $w, $h, %opts) {
        for my $row (0 .. $h - 1) {
            my $row_pos = $pos_vec * ZTUI::Matrix3::translate(0, -$row);
            $self->render_text($row_pos, $self->blank x $w, %opts);
        }
    }

    sub _render_quad($self, $pos_vec, $h, $w, %opts) {
        for my $row (0 .. $h - 1) {
            my $row_pos = $pos_vec * ZTUI::Matrix3::translate(0, -$row);
            $self->render_style($row_pos, $w, %opts);
        }
    }

    sub render_quad($self, $pos_vec, $quad) {
        if (defined $self->{theme}) {
            $self->render_rect($pos_vec, $quad->width, $quad->height,
                -material => $quad->material);
            return;
        }
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
        my %opts = defined($self->{theme})
            ? (-material => $material)
            : $self->mapper->style($material)->%*;
        my $glyph = $self->{blank};

        my $dx = abs($x1 - $x0);
        my $sx = $x0 < $x1 ? 1 : -1;
        my $dy = -abs($y1 - $y0);
        my $sy = $y0 < $y1 ? 1 : -1;
        my $err = $dx + $dy;

        while (1) {
            $self->render_text(ZTUI::Matrix3::Vec::from_xy($x0, $y0), $glyph, %opts);
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

    sub render_border($self, $pos_vec, $w, $h, %opts) {
        my $border_material = $opts{-border_material};
        confess "render_border requires -border_material"
            unless defined $border_material;

        my @edges = (
            [0, 0, 'TOP_LEFT', 0],
            [$w - 1, 0, 'TOP_RIGHT', 2],
            [0, $h - 1, 'BOTTOM_LEFT', 6],
            [$w - 1, $h - 1, 'BOTTOM_RIGHT', 8],
        );
        for my $col (1 .. $w - 2) {
            push @edges, [$col, 0, 'TOP', 1];
            push @edges, [$col, $h - 1, 'BOTTOM', 7];
        }
        for my $row (1 .. $h - 2) {
            push @edges, [0, $row, 'CENTER_LEFT', 3];
            push @edges, [$w - 1, $row, 'CENTER_RIGHT', 5];
        }

        for my $entry (@edges) {
            my ($dx, $dy, $edge, $glyph_idx) = $entry->@*;
            my $cell_pos = $pos_vec + ZTUI::Matrix3::Vec::from_xy($dx, -$dy);
            my $screen_pos = $cell_pos * $self->terminal_space;
            my ($col, $row) = _quantize_xy($screen_pos);
            my $border_style = $self->_resolve_border_style($border_material, $col, $row, $edge);
            my $glyph = $border_style->border->[$glyph_idx];
            $self->render_text($cell_pos, $glyph,
                -fg => $border_style->fg,
                -bg => $border_style->bg,
                -attrs => $border_style->attrs,
            );
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

        my @term_commands;
        for my $update (@updates) {
            my $payload = $update->{payload};
            my $step = int($update->{payload}->@* / $update->{size});
            my $outstr = "";

            my $terminal_state = undef;
            ZTUI::Utils::Array::for_batch {
                my ($cp, $fg, $bg, $attrs) = @_;

                if (!defined $terminal_state
                    || (   $fg    != $terminal_state->{fg}
                        || $bg    != $terminal_state->{bg}
                        || $attrs != $terminal_state->{attrs})) {
                    $outstr .= color(ZTUI::SGR::fg($fg)) if $fg != -1;
                    $outstr .= color(ZTUI::SGR::bg($bg)) if $bg != -1;
                    $outstr .= color(ZTUI::SGR::attrs($attrs)) // "" if defined $attrs && $attrs != -1;
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
            push @term_commands, [$outstr, $update->{col}, $update->{row}];
        }

        $self->term->write_batch(\@term_commands);
        $self->fbuf->sync($self->bbuf);
        $self->{frame_cache} = { material => {}, border => {} };
        $self->{frame_stamp}++;
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

    use ZTUI::Renderers;
    my $renderer = ZTUI::Renderers::DoubleBuffering::new($T, $H, $W, $theme, ' ');
    $renderer->initscr;
    $renderer->render_text($pos, "Hello", -material => 'DEFAULT');
    $renderer->flush;

=head1 DESCRIPTION

Renderers provides two renderer implementations used by the TUI:

ZTUI::Renderers::Naive writes directly to the terminal for every draw call.
ZTUI::Renderers::DoubleBuffering writes into a back buffer and flushes the
diff to the terminal.

Both implement a shared API for text, rects, borders, geometry, lines, and
buffer blits. The semantic renderer path resolves materials and border
materials through L<Theme>.

=head1 COMMON METHODS

=over 4

=item render_text($pos_vec, $text, %opts)

Renders text at a position. Semantic callers should pass C<-material> and
optional C<-justify>. The renderer also still accepts explicit C<-fg>,
C<-bg>, and C<-attrs> for lower-level compatibility.

=item render_rect($pos_vec, $w, $h, %opts)

Renders a filled rectangle. Semantic callers should pass C<-material>.

=item render_border($pos_vec, $w, $h, %opts)

Renders a border rectangle. Semantic callers should pass C<-border_material>.

=item render_quad($pos_vec, $quad)

Compatibility wrapper around rectangle rendering for older quad-based callers.

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
