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

# Represends a 2D buffer. Each element is a
# fixed size cell generated with pack($packstr, @values).
# 
# Use it to create data grids, each point will hold all
# data you need locally. For example:
#
#    my $buf = Renderers::PackBuffer2D::new("c4", 10, 10, 0, 0, 0, 255);
#
# Creates a 10x10 buffer, with stride 4 (bytes), occupying 10*10*4=400 bytes.
#
# Each cell will be initialized with "\0\0\0\xff". To get one cell you do:
#
#    my ($a, $b, $c, $d) = $buf->get($row, $col);
#
# To update a cell you do
#
#    $buf->set($row, $col, $a, $b, $c, $d);
#
# Implementation details:
#
# The internal buffer (accesible with $buf->buffer) is big PV. 2D coordinates
# (row x col) are projected into 1D buffer by the following pseudo code
#
#     sub get($self, $row, $col) {
#         my $idx = $row * $self->width + $col;
#         my $cell = substr($self->buffer, $idx * $self->stride, $self->stride)
#         unpack($self->packstr, $cell);
#     }
#
# This means that writes will automatically wrap arround over rows. I'm keeping
# this behavior because I think it may be useful later, but commenting it here
# because I also think it will bite me later.
#
# Also note that the API of this class is very convoluted, because I didn't now
# how I would use it from the start, I will cleanup it later, once the usecase
# settle.
#
# @TODO: Add safe variants of get/set that do not wrap arround or, change
#        get/set behavior to not wrap arround by default and add wrap arround versions of
#        get/set.
package Renderers::PackedBuffer2D {
    use v5.36;
    use integer;

    use Carp;
    use FindBin qw($Bin);
    use lib "$Bin";
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

    sub new($packstr, $H, $W, @defaults) {
        my $stride = length(pack($packstr));
        my $size = $H * $W;
        my $bytes = $size * $stride;
        my $buffer = pack($packstr, @defaults) x $size;
        my $zbuffer = $buffer;
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

    sub set_packed($self, $col, $row, $packed_values) {
        $self->set_1d_packed($row * $self->width + $col, $packed_values);
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
        $self->eq_1d_packed($row * $self->width + $col, pack($self->packstr, @values));
    }

    sub reset($self) {
        $self->{buffer} = $self->zbuffer;
    }

    sub copy_from($self, $other) {
        confess("Buffer dimensions mismatch during copy_from")
            if ($self->{width} != $other->{width} || $self->{height} != $other->{height});

        # Perl handles this as a shallow pointer copy until modification
        $self->{buffer} = $other->{buffer};
    }

    sub to_ansi_string($self) {
        use Term::ANSIColor qw(colored);
        my $out = "";
        my $width = $self->{width};
        my $height = $self->{height};

        for my $y (0 .. $height - 1) {
            # Track state to minimize redundant escape codes
            my ($last_fg, $last_bg, $last_at) = (-2, -2, -2);

            for my $x (0 .. $width - 2) {
                my ($cp, $fg, $bg, $at) = $self->get($x, $y); # should be $y, $x?
                confess "oops get($x, $y) $self->{width} x $self->{height} returned undef"
                    unless defined $cp;
                my @styles;

                push @styles, SGR::fg($fg)    if $fg != -1;
                push @styles, SGR::bg($bg)    if $bg != -1;
                push @styles, SGR::attrs($at) if $at != -1;

                my $char = $cp == 0 ? "." : chr($cp);
                if (@styles) {
                    $out .= colored($char, @styles);
                } else {
                    $out .= $char;
                }
            }
            $out .= "\n";
        }
        return $out;
    }
}

package Renderers::DoubleBuffering::Queue {
    use v5.36;
    use Utils qw(getters);
    
    use overload 
        '@{}' => \&to_array_ref,
        ;

    sub new() {
        bless {
            rows => {},
        }, __PACKAGE__;
    }

    sub enqueue($self, $col, $row, $glyph, $fg = -1, $bg = -1, $attrs = -1) {
        # 1. Find a candidate span on this row with matching metadata
        # We look for a span that either touches this column or contains it.
        my ($target) = grep {
            my $start = $_->{col};
            my $end   = $start + length($_->{payload});
            
            # Condition: Matching colors/attrs AND ($col is adjacent OR $col is inside)
            $_->{fg} == $fg && $_->{bg} == $bg && $_->{attrs} == $attrs &&
            $col >= $start && $col <= $end
        } $self->{rows}->{$row}->@*;

        if ($target) {
            # Calculate where in the string this glyph belongs
            my $offset = $col - $target->{col};
            
            # substr replacement: 
            # If offset == length, it appends.
            # If offset < length, it overwrites.
            substr($target->{payload}, $offset, 1) = $glyph;
            return;
        }

        # 2. No matching span found, create a new one
        push $self->{rows}->{$row}->@*, {
            fg      => $fg,
            bg      => $bg,
            col     => $col,
            row     => $row,
            attrs   => $attrs,
            payload => $glyph,
        };
    }

    sub to_array_ref($self, $other = undef, $swap = undef) {
        my @array;
        my @rows_keys = sort { $a <=> $b } keys $self->{rows}->%*;
        for my $row_key (@rows_keys) {
            push @array, $self->{rows}->{$row_key}->@*;
        }
        \@array;
    }

    sub to_string($self) {
        my @lines;
        my @rows_keys = sort { $a <=> $b } keys $self->{rows}->%*;
        for my $row_key (@rows_keys) {
            my $row = $self->{rows}->{$row_key};
            my @line;
            for my $span ($row->@*) {
                push @line, sprintf "row %3d col %3d text <%s>",
                    $span->{row},
                    $span->{col},
                    $span->{payload}
            }
            push @lines, join " | ", @line;
        }
        join "\n", @lines;
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
        queue
    );

    sub new($terminal_space, $H, $W, $blank = '.') {
        my $packstr = "l4";
        my @default = (ord($blank), -1, -1, -1);
        my $bbuf = Renderers::PackedBuffer2D::new($packstr, $H, $W, @default);
        my $fbuf = Renderers::PackedBuffer2D::new($packstr, $H, $W, @default);
        bless {
            bbuf => $bbuf,
            fbuf => $fbuf,
            blank => $blank,
            height => $H,
            terminal_space => $terminal_space,
            width => $W,
            packstr => $packstr,
            term => Termlib::new(),
            queue => Renderers::DoubleBuffering::Queue::new(),
        }, __PACKAGE__;
    }

    sub initscr($self) {
        $self->term->initscr($self->blank);
    }

    sub render_geometry($self, $pos_vec, $geo) {
        for my $point ($geo->@*) {
            my ($pos, $text, $fg, $bg, $attrs) = $point->@*;
            $self->render_text($pos + $pos_vec, $text,
                -fg     => $fg,
                -bg     => $bg,
                -attrs => $attrs,
            );
        }
    }

    sub erase_geometry($self, $pos_vec, $geo, $char = undef) {
        my $blank = $char // $self->blank;
        for my $point ($geo->@*) {
            my ($pos, $text, $fg, $bg, $attrs) = $point->@*;
            $self->render_text($pos + $pos_vec, $blank x length($text));
        }
    }


    sub render_text($self, $pos_vec, $text, %opts) {
        # say "render_text $text";
        $opts{$_} //= -1
            for qw(-fg -bg -attrs);
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

        for my $codepoint (split //u, $text) {
            $self->_render_point($pos, $codepoint, $fg, $bg, $attrs);
            $pos *= $EAST;
        }
    }

    sub render_fmt($self, $pos_vec, $fmt, @args) {
        $self->render_text($pos_vec, sprintf($fmt, @args));
    }

    sub _render_point($self, $pos_vec, $glyph, $fg = -1, $bg = -1, $attrs = -1) {
        my $pack = $self->_pack($glyph, $fg, $bg, $attrs);
        # # front buffer is already updated, nothing to do
        my $fbuf_pack = $self->fbuf->get_packed($pos_vec->@*);
        # say sprintf "render_point $glyph fbuf %s, bbuf %s",
        #     unpack("H*", $pack),
        #     unpack("H*", $fbuf_pack);
        return if $self->fbuf->eq_packed($pos_vec->@*, $pack);
        $self->bbuf->set_packed($pos_vec->@*, $pack);
        $self->queue->enqueue($pos_vec->@*, $glyph, $fg, $bg, $attrs);
    }

    sub flush($self) {
        for my $command ($self->queue->@*) {
            # say sprintf "executing command: row %3d col %3d text %s",
            #     $command->{row}, $command->{col}, $command->{payload};
            $self->term->write_color(
                $command->{payload},
                $command->{col},
                $command->{row},
                $command->{fg},
                $command->{bg},
               $command->{attrs});
        }
        $self->reset();

        undef;
    }

    sub reset($self) {
        # swap buffers and reset the queue
        ($self->{fbuf}, $self->{bbuf}) = ($self->bbuf, $self->fbuf);
        # $self->bbuf->copy_from($self->fbuf);
        $self->{queue} = Renderers::DoubleBuffering::Queue::new();
    }

    sub _pack($self, $glyph, $fg = -1 , $bg = -1, $attrs = -1) {
        confess "null glyph" if !defined $glyph;
        pack($self->packstr, ord($glyph), $fg, $bg, $attrs);
    }

}


1;
