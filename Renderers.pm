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

package Renderers::Buffer2D {
    use v5.36;
    use Carp;
    use FindBin qw($Bin);
    use lib "$Bin";
    use Utils qw(getters);

    getters qw(
        H
        W
        bsize
        buf
        defaults
        opts
        packstr
        size
        stride
        zeroed
    );

    sub new($packstr, $H, $W, $defaults, %opts) {
        my $stride = length(pack($packstr));
        my $size = $W * $H;
        my $bsize = $size * $stride;
        my $buf = pack($packstr, $defaults->@*) x $size;
        my $zeroed = $buf;
        $opts{-autoclip} //= 0;
        bless {
            H => $H,
            W => $W,
            _updated_rows => {},
            bsize => $bsize,
            buf => $buf,
            defaults => $defaults,
            opts => \%opts,
            packstr => $packstr,
            size => $size,
            stride => $stride,
            zeroed => $zeroed,
        }, __PACKAGE__;
    }

    sub from_other($other) {
        # This 
        my $self = { $other->%* };
        $self->{defaults} = [ $other->defaults->@* ];
        $self->{_updated_rows} = {};
        return bless $self, __PACKAGE__;

        # Instead of this;
        return bless {
            H => $other->H,                     # int
            W => $other->W,                     # int
            _updated_rows => {},
            bsize => $other->bsize,             # int
            buf => $other->buf,                 # string (Cow)
            defaults => [$other->defaults->@*], # array ref
            packstr => $other->packstr,         # string (CoW)
            opts => { $other->opts->%* },
            size => $other->size,               # int
            stride => $other->stride,           # int
            zeroed => $other->zeroed,
        }, __PACKAGE__;
    }

    sub copy($self) {
        Renderers::Buffer2D::from_other($self);
    }

    sub valid($self, $col, $row, $length = 1) {
        my $colend = $col + $length - 1;
        0 <= $col && $col < $self->W
            && $col <= $colend && $colend < $self->W
            && 0 <= $row && $row < $self->H;
    }

    sub clip($self, $col, $row, $length) {
        use List::Util qw(min max);

        my $newcol = max(min($col, $self->W - 1), 0);
        my $newrow = max(min($row, $self->H - 1), 0);
        return ($newcol, $newrow, 0) if $length <= 0;
        return ($newcol, $newrow, 0)
            if $row < 0 || $row >= $self->H;

        my $start = max($col, 0);
        my $end = min($col + $length - 1, $self->W - 1);
        my $newlength = $end - $start + 1;
        return ($newcol, $newrow, 0) if $newlength <= 0;

        ($start, $row, $newlength);
    }

    sub index_unchecked($self, $col, $row) {
        (($row * $self->W) + $col) * $self->stride;
    }

    sub index($self, $col, $row, $length) {
        if ($self->opts->{-autoclip}) {
            my ($ccol, $crow, $clength) = $self->clip($col, $row, $length);
            return (undef, 0, 0) if $clength <= 0;
            my $skip = $ccol - $col;
            return ($self->index_unchecked($ccol, $crow), $clength * $self->stride, $skip);
        } else {
            confess "invalid access" 
                unless $self->valid($col, $row, $length);
            return ($self->index_unchecked($col, $row), $length * $self->stride, 0);
        }
    }

    sub getp($self, $col, $row) {
        my ($idx, $length) = $self->index($col, $row, 1);
        return undef if !$length;
        substr($self->buf, $idx, $length);
    }

    sub getp_unchecked($self, $col, $row) {
        my $idx = $self->index_unchecked($col, $row);
        substr($self->buf, $idx, $self->stride);
    }

    sub get($self, $col, $row) {
        my ($idx, $length) = $self->index($col, $row, 1);
        return if !$length;
        unpack($self->packstr, substr($self->buf, $idx, $length));
    }

    sub setp($self, $col, $row, $payload) {
        my ($idx, $length) = $self->index($col, $row, 1);
        return if !$length;
        $self->{_updated_rows}->{$row}++;
        substr($self->{buf}, $idx, $length) = $payload;
        $self->{_updated_rows}->{$row}++;
    }


    sub set($self, $col, $row, $values) {
        my ($idx, $length) = $self->index($col, $row, 1);
        return if !$length;
        substr($self->{buf}, $idx, $length) = pack($self->packstr, $values->@*);
        $self->{_updated_rows}->{$row}++;
    }

    sub update($self, $col, $row, $values) {
        $self->update_multi($col, $row, $values);
    }

    sub get_multi($self, $col, $row, $n) {
        my $stride = $self->stride;
        my ($idx, $length) = $self->index($col, $row, $n);
        return if !$length;
        my $count = $length / $stride;
        my $payloads = substr($self->{buf}, $idx, $length);
        my @values;
        for (0 .. $count - 1) {
            my $payload = substr($payloads, $_ * $stride);
            push @values, [ unpack($self->packstr, $payload) ];
        }

        @values;
    }

    sub get_multi_unchecked($self, $col, $row, $n) {
        my $stride = $self->stride;
        my $idx = $self->index_unchecked($col, $row);
        my $length = $n * $stride;
        my $payloads = substr($self->{buf}, $idx, $length);
        my @values;
        for (0 .. $n - 1) {
            my $payload = substr($payloads, $_ * $stride);
            push @values, [ unpack($self->packstr, $payload) ];
        }

        @values;
    }

    sub set_multi($self, $col, $row, @values) {
        my $stride = $self->stride;
        my ($idx, $length, $skip) = $self->index($col, $row, scalar @values);
        return if !$length;
        my $count = $length / $stride;
        my @clipped = @values[$skip .. $skip + $count - 1];
        confess "undef in payload" if
            grep { !defined } map { $_->@* } @clipped;
        my $payload = pack(sprintf("(%s)*", $self->packstr), map { $_->@* } @clipped);
        substr($self->{buf}, $idx, $length) = $payload;
        $self->{_updated_rows}->{$row}++;
    }

    sub set_multi_unchecked($self, $col, $row, @values) {
        my $stride = $self->stride;
        my $idx = $self->index_unchecked($col, $row);
        my $length = scalar(@values) * $stride;
        confess "undef in payload" if
            grep { !defined } map { $_->@* } @values;
        my $payload = pack(sprintf("(%s)*", $self->packstr), map { $_->@* } @values);
        substr($self->{buf}, $idx, $length) = $payload;
        $self->{_updated_rows}->{$row}++;
    }

    sub _merge_payload($payload, $values, $offset, $count) {
        for (my $i = 0; $i < $count; $i++) {
            my $src = $values->[$offset + $i];
            for (my $j = 0; $j < $src->@*; $j++) {
                $payload->[$i][$j] = $src->[$j]
                    if defined $src->[$j];
            }
        }
    }

    sub update_multi($self, $col, $row, @values) {
        my $n = scalar @values;
        return if $n <= 0;
        my $valid = $self->valid($col, $row, $n);
        if ($valid) {
            my @payload = $self->get_multi_unchecked($col, $row, $n);
            _merge_payload(\@payload, \@values, 0, $n);
            $self->set_multi_unchecked($col, $row, @payload);
            return;
        }

        confess "invalid access" if $self->opts->{-autoclip} == 0;

        my $stride = $self->stride;
        my ($idx, $length, $skip) = $self->index($col, $row, $n);
        return if !$length;
        my $count = $length / $stride;
        my @payload = $self->get_multi($col + $skip, $row, $count);
        _merge_payload(\@payload, \@values, $skip, $count);
        $self->set_multi($col + $skip, $row, @payload);
    }

    sub xor_inplace($self, $other) {
        $self->{buf} ^.= $other->buf;
    }

    sub diff($self, $other) {
        my $delta = $self->copy;
        $delta->xor_inplace($other);
        my @indexes;
        my $zero = "\0" x $delta->stride;
        my $stride = $self->stride;
        my $row_stride = $self->{W} * $stride;
        my $pack_template = sprintf("(%s)*", $self->packstr);
        for my $row (sort { $a <=> $b } keys $self->{_updated_rows}->%*) {
            next if $row < 0 || $row >= $self->{H};
            my $row_base = $row * $row_stride;
            my $col = 0;
            while ($col < $self->{W}) {
                my $idx = $row_base + $col * $stride;
                my $pack = substr($delta->{buf}, $idx, $stride);
                if ($pack eq $zero) {
                    $col++;
                    next;
                }

                my $start = $col;
                $col++;
                while ($col < $self->{W}) {
                    $idx = $row_base + $col * $stride;
                    $pack = substr($delta->{buf}, $idx, $stride);
                    last if $pack eq $zero;
                    $col++;
                }
                my $size = $col - $start;
                my $payload_bytes = substr($self->{buf}, $row_base + $start * $stride, $size * $stride);
                my @payload = unpack($pack_template, $payload_bytes);
                push @indexes, {
                    col => $start,
                    row => $row,
                    payload => \@payload,
                    size => $size,
                };
            }
        }
        $self->{_updated_rows} = {};
        @indexes;
    }
    
    sub sync($self, $other) {
        $self->{buf} = $other->buf;
    }

    sub to_string($self, @ignored) {
        my @lines;
        for my $row (0 .. $self->H - 1) {
            push @lines, unpack("H*", 
                    substr($self->buf,
                        $row * $self->W * $self->stride,
                        $self->stride * $self->W));

        }
        join "\n", @lines;
    }

    sub reset($self) {
        $self->{buf} = $self->zeroed;
    }

}


package Renderers::DoubleBuffering {
    use v5.36;
    use utf8;
    use Carp;
    use Data::Dumper;
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

        my $bbuf = Renderers::Buffer2D::new($packstr, $H, $W, \@default, -autoclip => 1);
        my $fbuf = Renderers::Buffer2D::new($packstr, $H, $W, \@default, -autoclip => 1);
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
