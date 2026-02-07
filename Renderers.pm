package Renderers::Naive {
    use v5.36;
    use FindBin qw($Bin);
    use Carp;
    use lib "$Bin";

    use Matrix3;
    use Termlib;
    use Utils qw(getters);

    getters qw(terminal_space term blank);
    
    sub new($terminal_space, $blank = '.') {
        bless {
            terminal_space => $terminal_space,
            term => Termlib::new(),
            blank => $blank,
        }, __PACKAGE__,
    }

    sub initscr($self) {
        $self->term->initscr($self->blank);
    }

    sub render_geometry($self, $at_vec, $geo) {
        use integer;
        my $coord_mapper = $self->terminal_space * Matrix3::translate($at_vec->@*);
        for my $point ($geo->@*) {
            my ($pos_vec, $value) = $point->@*;
            $self->term->write_vec($value, $pos_vec * $coord_mapper);
        }
    }

    sub erase_geometry($self, $at_vec, $geo, $char) {
        use integer;
        my $coord_mapper = $self->terminal_space * Matrix3::translate($at_vec->@*);
        for my $point ($geo->@*) {
            my ($pos_vec, $value) = $point->@*;
            $self->term->write_vec($char x length($value), $pos_vec * $coord_mapper);
        }
    }

    sub render_text($self, $at_vec, $text, %opts) {
        use integer;
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
        $self->render_text($at_vec, sprintf($fmt, @args));
    }

    sub flush($self) {
    }
}

package Renderers::PackedBuffer2D {
    use v5.36;
    use Utils qw(getters);

    getters qw(
        bytes
        buffer
        height
        packstr
        size
        stride
        width
        zbuffer
    );

    sub new($packstr, $H, $W) {
        my $stride = length(pack($packstr));
        my $size = $H * $W;
        my $bytes = $size * $stride;
        my $buffer = "\0" x $bytes;
        my $zbuffer = "\0" x $bytes;
        bless {
            buffer => $buffer,
            bytes => $bytes,    # size in bytes
            height => $H,
            packstr => $packstr,
            size => $size,      # size in bytes / stride
            stride => $stride,
            width => $W,
            zbuffer => $zbuffer,
        }, __PACKAGE__;
    }

    sub get_1d_packed($self, $nth) {
        substr($self->buffer, $nth * $self->stride, $self->stride);
    }

    sub get_1d($self, $nth) {
        unpack($self->packstr, $self->get_1d_packed($nth));
    }

    sub get_packed($self, $col, $row) {
        $self->get_1d_packed($row * $self->width + $col);
    }

    sub get($self, $col, $row) {
        $self->get_1d($row * $self->width + $col);
    }

    sub set_1d_packed($self, $nth, $packed_values) {
        substr($self->{buffer}, $nth * $self->stride, $self->stride) = $packed_values;
        undef;
    }
    
    sub set_1d($self, $nth, @values) {
        $self->set_1d_packed($nth, pack($self->packstr, @values));
        undef;
    }

    sub set($self, $col, $row, @values) {
        $self->set_1d_packed($row * $self->width + $col, pack($self->packstr, @values));
    }

    sub eq_1d_packed($self, $nth, $packed_values) {
        substr($self->buffer, $nth * $self->stride, $self->stride) eq $packed_values;
    }


    sub eq_packed($self, $col, $row, $packed_values) {
        $self->eq_1d_packed($row * $self->width + $col, $packed_values);
    }

    sub eq($self, $col, $row, @values) {
        $self->eq_1d_packed($row * $col, pack($self->packstr, @values));
    }

    sub reset($self) {
        $self->{buffer} = $self->zbuffer;
    }
}

package Renderers::DoubleBuffering {
    use v5.36;
    use Utils qw(getters);
    use Matrix3 qw($EAST);
    no autovivification;

    getters qw(
        terminal_space
        height
        width
        queue
    );

    sub new($terminal_space, $H, $W, $blank = '.') {
        my $packstr = "l4";
        my $bbuf = Renderers::PackedBuffer2D::new($packstr, $H, $W);
        my $fbuf = Renderers::PackedBuffer2D::new($packstr, $H, $W);
        bless {
            bbuf => $bbuf,
            fbuf => $fbuf,
            blank => $blank,
            height => $H,
            terminal_space => $terminal_space,
            width => $W,
            packstr => $packstr,
            term => Termlib::new(),
            queue => [],
        }, __PACKAGE__;
    }

    sub render_geometry($self, $pos_vec, $geo) {
        for my $point ($geo->@*) {
            $self->render_text($point->@*);
        }
    }

    sub render_text($self, $pos_vec, $text, $fg = undef, $bg = undef, $attrs = undef) {
        my $pos = $pos_vec->copy;
        for my $codepoint (split //u, $text) {
            $pos *= $EAST;
            render_point($pos, $codepoint, $fg, $bg, $attrs);
        }
    }

    sub render_point($self, $pos_vec, $glyph, $fg = undef, $bg = undef, $attrs = undef) {
        my $pack = $self->_pack($glyph, $fg, $bg, $attrs);
        # front buffer is already updated, nothing to do
        return if $self->fbuf->eq_packed($pos_vec->@*, $pack);

        $self->enqueue($pos_vec, $glyph, $fg, $bg, $attrs);
    }

    sub enqueue($self, $pos_vec, $glyph, $fg = undef, $bg = undef, $attrs = undef) {
        my ($col, $row) = $pos_vec->@*;
        if ($self->queue->@*) {
            my $last = $self->queue->[$self->queue->$#*];
            if ($last->{row} eq $row &&
                $last->{col} + 1 eq $col &&
                $last->{fg} eq $fg &&
                $last->{bg} eq $bg &&
                $last->{attrs} eq $attrs
            ) {
                $last->{payload} .= $glyph;
            }
        }

        push $self->queue->@*, {
            row => $col,
            col => $row,
            payload => $glyph,
            fg => $fg,
            bg => $bg,
            attrs => $attrs,
        }
    }

    sub flush($self) {
        for my $command ($self->queue->@*) {
            $self->term->write_color(
                $command->{payload},
                $command->{fg},
                $command->{bg},
                $command->{attrs})
        }
        $self->{queue} = [];

        undef;
    }


    sub _pack($self, $glyph, $fg = undef, $bg = undef, $attrs = undef) {
        pack($self->packstr, $fg // -1, $bg // -1, $attrs // 0);
    }

}


1;
