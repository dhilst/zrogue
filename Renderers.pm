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

package Renderers::PackedBuffer2D::Command {
    use v5.36;
    use Term::ANSIColor qw(colored);
    use Utils qw(getters);

    use constant {
        ATTR_BOLD      => 1 << 0, # 1
        ATTR_DIM       => 1 << 1, # 2
        ATTR_ITALIC    => 1 << 2, # 4
        ATTR_UNDERLINE => 1 << 3, # 8
        ATTR_BLINK     => 1 << 4, # 16
        ATTR_REVERSE   => 1 << 5, # 32
    };

    getters qw(
        attrs
        bg
        col
        fg
        payload
        row
    );

    sub new($col, $row, $fg = 0, $bg = 0, $attrs = [], $payload = "") {
        bless {
            attrs => $attrs,        # 32bit
            bg => $bg,              # 32bit
            col => $col,            # 32bit
            fg => $fg,              # 32bit
            payload => $payload,    # string
            row => $row,            # 32bit
        }, __PACKAGE__;
    }

    sub to_sgr($self) {
        my $bg = _rgb("on_", $self->bg);
        my $fg = _rgb("", $self->fg);
        colored($self->payload, [_attr_to_strs($self->attrs), $fg, $bg]);
    }

    sub _rbg($prefix, $color) {
        sprintf "%sr%dg%db%d",
            $prefix,
            ($color >> 16),
            ($color >> 8 & 0xff),
            ($color & 0xff),

    }

    sub _attr_to_strs($attrs) {
        my @attrs;
        push @attrs, "bold" if $attrs & ATTR_BOLD;
        push @attrs, "dim" if $attrs & ATTR_DIM;
        push @attrs, "italic" if $attrs & ATTR_ITALIC;
        push @attrs, "blink" if $attrs & ATTR_BLINK;
        push @attrs, "reverse" if $attrs & ATTR_REVERSE;
        @attrs;
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

    getters qw(
        terminal_space
        height
        width
    );

    sub new($terminal_space, $H, $W, $blank = '.') {
        my $packstr = "L4";
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
        }, __PACKAGE__;
    }

    sub render_text($self, $pos_vec, $text, $fg = undef, $bg = undef, @attrs) {

    }

}


1;
