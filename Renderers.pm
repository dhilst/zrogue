package Renderers::Naive {
    use v5.36;
    use FindBin qw($Bin);
    use Carp;
    use lib "$Bin";
    use integer;

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
        packstr
        size
        stride
        zeroed
    );

    sub new($packstr, $H, $W, $defaults) {
        my $stride = length(pack($packstr));
        my $size = $W * $H;
        my $bsize = $size * $stride;
        my $buf = pack($packstr, $defaults->@*) x $size;
        my $zeroed = $buf;
        bless {
            H => $H,
            W => $W,
            _updated_rows => {},
            bsize => $bsize,
            buf => $buf,
            defaults => $defaults,
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
            size => $other->size,               # int
            stride => $other->stride,           # int
            zeroed => $other->zeroed,
        }, __PACKAGE__;
    }

    sub copy($self) {
        Renderers::Buffer2D::from_other($self);
    }

    sub valid($self, $col, $row) {
        0 <= $col && $col < $self->W
            && 0 <= $row && $row < $self->H;
    }

    sub getp($self, $col, $row) {
        confess "invalid access" unless $self->valid($col, $row);
        my $idx = ($row * $self->W + $col) * $self->stride;
        substr($self->buf, $idx, $self->stride);
    }

    sub get($self, $col, $row) {
        confess "invalid access" unless $self->valid($col, $row);
        my $idx = ($row * $self->W + $col) * $self->stride;
        unpack($self->packstr, substr($self->buf, $idx, $self->stride));
    }

    sub setp($self, $col, $row, $payload) {
        confess "invalid access" unless $self->valid($col, $row);
        $self->{_updated_rows}->{$row}++;
        my $idx = ($row * $self->W + $col) * $self->stride;
        substr($self->{buf}, $idx, $self->stride) = $payload;
    }

    sub set($self, $col, $row, $values) {
        confess "invalid access" unless $self->valid($col, $row);
        my $idx = ($row * $self->W + $col) * $self->stride;
        substr($self->{buf}, $idx, $self->stride) = pack($self->packstr, $values->@*);
        $self->{_updated_rows}->{$row}++;
    }

    sub get_multi($self, $col, $row, $n) {
        confess "invalid access" unless
            $self->valid($col, $row) &&
            $self->valid($col + $n - 1, $row);
        my $stride = $self->stride;
        my $idx = ($row * $self->W + $col) * $stride;
        my $payloads = substr($self->{buf}, $idx, $n * $stride);
        my @values;
        for (0 .. $n - 1) {
            my $payload = substr($payloads, $_ * $stride);
            push @values, [ unpack($self->packstr, $payload) ];
        }

        @values;
    }

    sub set_multi($self, $col, $row, @values) {
        confess "invalid access" unless
            $self->valid($col, $row) &&
            $self->valid($col + $#values, $row);
        my $stride = $self->stride;
        my $payload = pack(sprintf("(%s)*", $self->packstr), map { $_->@* } @values);
        my $idx = ($row * $self->W + $col) * $stride;
        substr($self->{buf}, $idx, (scalar @values) * $stride) = $payload;
        $self->{_updated_rows}->{$row}++;
    }

    sub xor_inplace($self, $other) {
        $self->{buf} ^.= $other->buf;
    }

    sub diff($self, $other) {
        my $delta = $self->copy;
        $delta->xor_inplace($other);
        my @indexes;
        my $zero = "\0" x $delta->stride;
        for my $row (sort { $a <=> $b } keys $self->{_updated_rows}->%*) {
            for my $col(0 .. $self->{W} - 1) {
                my $pack = $delta->getp($col, $row);
                confess if !defined $pack;
                if ($pack ne $zero) {
                    my $payload = $self->getp($col, $row);
                    my $last = $indexes[$#indexes];

                    if (defined $last && $last->{row} == $row 
                        && $last->{col} + $last->{size} == $col
                    ) {
                        push $last->{payload}->@*, unpack($self->packstr, $payload);
                        $last->{size}++;
                        next;
                    }

                    my @payload = unpack($self->packstr, $payload);
                    push @indexes, { 
                        col => $col, 
                        row => $row, 
                        payload => \@payload,
                        size => 1,
                    };
                }
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
    );

    sub new($terminal_space, $H, $W, $blank = '.') {
        my $packstr = "l4";
        my @default = (ord($blank), -1, -1, -1);
        my $bbuf = Renderers::Buffer2D::new($packstr, $H, $W, \@default);
        my $fbuf = Renderers::Buffer2D::new($packstr, $H, $W, \@default);
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

    sub initscr($self) {
        $self->term->initscr($self->blank);
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

        my @unpacked;
        for my $codepo (split //u, $text) {
            push @unpacked, [ord($codepo), $fg, $bg, $attrs];
        }

        # say "Prerendering <$text>";
        $self->bbuf->set_multi($pos->@*, @unpacked);
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
                    $outstr .= color(SGR::bg($fg)) if $bg != -1;
                    $outstr .= color(SGR::attrs($fg)) if $attrs != -1;
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
