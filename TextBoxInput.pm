package TextBoxInput;

use v5.36;
use utf8;
use Carp;

use lib ".";
use Utils qw(getters);
use Event;
use Matrix3;

getters qw(
    lines
    cursor_row
    cursor_col
    max_w
    max_h
    material_focus
    material_blur
    focused
    scroll_top
    submitted
    cancelled
    submit_on_enter
);

sub new(%opts) {
    confess "missing -max_w" unless defined $opts{-max_w};
    confess "missing -max_h" unless defined $opts{-max_h};
    my $max_w = int($opts{-max_w});
    my $max_h = int($opts{-max_h});
    confess "max_w must be >= 2" if $max_w < 2;
    confess "max_h must be >= 1" if $max_h < 1;

    my $self = bless {
        lines => [''],
        cursor_row => 0,
        cursor_col => 0,
        max_w => $max_w,
        max_h => $max_h,
        material_focus => $opts{-material_focus},
        material_blur => $opts{-material_blur},
        focused => 0,
        scroll_top => 0,
        submitted => 0,
        cancelled => 0,
        submit_on_enter => $opts{-submit_on_enter} ? 1 : 0,
    }, __PACKAGE__;

    $self->set_text($opts{-text} // '');

    if (defined $opts{-cursor}) {
        confess "cursor must be arrayref" unless ref($opts{-cursor}) eq 'ARRAY';
        my ($row, $col) = $opts{-cursor}->@*;
        $self->{cursor_row} = $row < 0 ? 0 : $row;
        $self->{cursor_row} = $self->{lines}->$#*
            if $self->{cursor_row} > $self->{lines}->$#*;
        my $len = length($self->{lines}->[$self->{cursor_row}] // '');
        $self->{cursor_col} = $col < 0 ? 0 : $col;
        $self->{cursor_col} = $len if $self->{cursor_col} > $len;
        $self->_ensure_scroll;
    }

    $self;
}

sub text_width($self) {
    $self->{max_w} - 1;
}

sub text($self) {
    join "\n", $self->{lines}->@*;
}

sub clear_flags($self) {
    $self->{submitted} = 0;
    $self->{cancelled} = 0;
}

sub set_text($self, $text) {
    $text //= '';
    my $width = $self->text_width;
    my @raw = split /\n/, $text, -1;
    my @lines;
    for my $line (@raw) {
        while (length($line) > $width) {
            push @lines, substr($line, 0, $width);
            $line = substr($line, $width);
        }
        push @lines, $line;
    }
    @lines = ('') unless @lines;
    $self->{lines} = \@lines;
    $self->{cursor_row} = $#lines;
    $self->{cursor_col} = length($lines[$#lines]);
    $self->{scroll_top} = 0;
    $self->_ensure_scroll;
}

sub clear($self) {
    $self->{lines} = [''];
    $self->{cursor_row} = 0;
    $self->{cursor_col} = 0;
    $self->{scroll_top} = 0;
    1;
}

sub focus($self) { $self->{focused} = 1; }
sub blur($self) { $self->{focused} = 0; }

sub _ensure_scroll($self) {
    my $count = $self->{lines}->@*;
    my $height = $self->{max_h};
    if ($count <= $height) {
        $self->{scroll_top} = 0;
        return;
    }
    $self->{scroll_top} = 0 if $self->{scroll_top} < 0;
    my $max_top = $count - $height;
    $self->{scroll_top} = $max_top if $self->{scroll_top} > $max_top;
    if ($self->{cursor_row} < $self->{scroll_top}) {
        $self->{scroll_top} = $self->{cursor_row};
    } elsif ($self->{cursor_row} >= $self->{scroll_top} + $height) {
        $self->{scroll_top} = $self->{cursor_row} - $height + 1;
    }
}

sub _wrap_from($self, $row) {
    my $width = $self->text_width;
    my $lines = $self->{lines};
    return if $width <= 0;
    while ($row < $lines->@*) {
        my $line = $lines->[$row];
        last if length($line) <= $width;
        my $overflow = substr($line, $width);
        $lines->[$row] = substr($line, 0, $width);
        if ($row + 1 < $lines->@*) {
            $lines->[$row + 1] = $overflow . $lines->[$row + 1];
        } else {
            push $lines->@*, $overflow;
        }
        if ($self->{cursor_row} == $row && $self->{cursor_col} > $width) {
            $self->{cursor_row}++;
            $self->{cursor_col} -= $width;
        }
        $row++;
    }
}

sub insert_text($self, $text) {
    return 0 unless defined $text && length($text) > 0;
    my $changed = 0;
    for my $ch (split //u, $text) {
        if ($ch eq "\n") {
            $changed = 1 if $self->insert_newline;
        } else {
            $changed = 1 if $self->insert_char($ch);
        }
    }
    $changed;
}

sub insert_char($self, $ch) {
    return 0 unless defined $ch && length($ch);
    my $row = $self->{cursor_row};
    my $col = $self->{cursor_col};
    my $line = $self->{lines}->[$row];
    substr($line, $col, 0, $ch);
    $self->{lines}->[$row] = $line;
    $self->{cursor_col}++;
    $self->_wrap_from($row);
    $self->_ensure_scroll;
    1;
}

sub insert_newline($self) {
    my $row = $self->{cursor_row};
    my $col = $self->{cursor_col};
    my $line = $self->{lines}->[$row];
    my $before = substr($line, 0, $col);
    my $after = substr($line, $col);
    $self->{lines}->[$row] = $before;
    splice $self->{lines}->@*, $row + 1, 0, $after;
    $self->{cursor_row}++;
    $self->{cursor_col} = 0;
    $self->_wrap_from($row);
    $self->_ensure_scroll;
    1;
}

sub backspace($self) {
    my $row = $self->{cursor_row};
    my $col = $self->{cursor_col};
    if ($col > 0) {
        my $line = $self->{lines}->[$row];
        substr($line, $col - 1, 1, '');
        $self->{lines}->[$row] = $line;
        $self->{cursor_col}--;
        $self->_ensure_scroll;
        return 1;
    }
    return 0 if $row <= 0;
    my $prev = $self->{lines}->[$row - 1];
    my $cur = $self->{lines}->[$row];
    my $new_col = length($prev);
    $self->{lines}->[$row - 1] = $prev . $cur;
    splice $self->{lines}->@*, $row, 1;
    $self->{cursor_row}--;
    $self->{cursor_col} = $new_col;
    $self->_wrap_from($self->{cursor_row});
    $self->_ensure_scroll;
    1;
}

sub delete_forward($self) {
    my $row = $self->{cursor_row};
    my $col = $self->{cursor_col};
    my $line = $self->{lines}->[$row];
    if ($col < length($line)) {
        substr($line, $col, 1, '');
        $self->{lines}->[$row] = $line;
        $self->_ensure_scroll;
        return 1;
    }
    return 0 if $row >= $self->{lines}->$#*;
    my $next = $self->{lines}->[$row + 1];
    $self->{lines}->[$row] = $line . $next;
    splice $self->{lines}->@*, $row + 1, 1;
    $self->_wrap_from($row);
    $self->_ensure_scroll;
    1;
}

sub move_left($self) {
    if ($self->{cursor_col} > 0) {
        $self->{cursor_col}--;
        $self->_ensure_scroll;
        return 1;
    }
    return 0 if $self->{cursor_row} <= 0;
    $self->{cursor_row}--;
    $self->{cursor_col} = length($self->{lines}->[$self->{cursor_row}]);
    $self->_ensure_scroll;
    1;
}

sub move_right($self) {
    my $row = $self->{cursor_row};
    my $col = $self->{cursor_col};
    my $line = $self->{lines}->[$row];
    if ($col < length($line)) {
        $self->{cursor_col}++;
        $self->_ensure_scroll;
        return 1;
    }
    return 0 if $row >= $self->{lines}->$#*;
    $self->{cursor_row}++;
    $self->{cursor_col} = 0;
    $self->_ensure_scroll;
    1;
}

sub move_up($self) {
    return 0 if $self->{cursor_row} <= 0;
    $self->{cursor_row}--;
    my $len = length($self->{lines}->[$self->{cursor_row}]);
    $self->{cursor_col} = $len if $self->{cursor_col} > $len;
    $self->_ensure_scroll;
    1;
}

sub move_down($self) {
    return 0 if $self->{cursor_row} >= $self->{lines}->$#*;
    $self->{cursor_row}++;
    my $len = length($self->{lines}->[$self->{cursor_row}]);
    $self->{cursor_col} = $len if $self->{cursor_col} > $len;
    $self->_ensure_scroll;
    1;
}

sub move_home($self) {
    return 0 if $self->{cursor_col} == 0;
    $self->{cursor_col} = 0;
    $self->_ensure_scroll;
    1;
}

sub move_end($self) {
    my $len = length($self->{lines}->[$self->{cursor_row}]);
    return 0 if $self->{cursor_col} == $len;
    $self->{cursor_col} = $len;
    $self->_ensure_scroll;
    1;
}

sub scrollbar_rows($self) {
    my $height = $self->{max_h};
    my @rows = (' ') x $height;
    my $total = $self->{lines}->@*;
    return @rows if $total <= $height;

    @rows = ('|') x $height;
    my $thumb_len = int($height * $height / $total);
    $thumb_len = 1 if $thumb_len < 1;
    $thumb_len = $height if $thumb_len > $height;
    my $max_scroll = $total - $height;
    my $thumb_top = $max_scroll > 0
        ? int($self->{scroll_top} * ($height - $thumb_len) / $max_scroll)
        : 0;
    for my $i (0 .. $thumb_len - 1) {
        $rows[$thumb_top + $i] = '#';
    }
    @rows;
}

sub display_rows($self) {
    my $width = $self->text_width;
    my $height = $self->{max_h};
    my @bar = $self->scrollbar_rows;
    my @rows;
    for my $i (0 .. $height - 1) {
        my $idx = $self->{scroll_top} + $i;
        my $line = $idx <= $self->{lines}->$#*
            ? $self->{lines}->[$idx]
            : '';
        $line = substr($line, 0, $width) if length($line) > $width;
        my $pad = $width - length($line);
        $line .= ' ' x $pad if $pad > 0;
        push @rows, $line . ($bar[$i] // ' ');
    }
    @rows;
}

sub render($self, $renderer, $pos_vec, %opts) {
    my %style;
    my $material = $self->{focused} ? $self->{material_focus} : $self->{material_blur};
    if (defined $material) {
        my $mapper = $renderer->mapper;
        if (ref($mapper) && $mapper->can('style')) {
            %style = $mapper->style($material)->%*;
        } else {
            %style = $mapper->($material)->%*;
        }
    }
    my @rows = $self->display_rows;
    for my $i (0 .. $#rows) {
        my $row_pos = $pos_vec + Matrix3::Vec::from_xy(0, -$i);
        $renderer->render_text($row_pos, $rows[$i], %style, %opts);
    }
}

sub update($self, @events) {
    my $changed = 0;
    for my $event (@events) {
        next unless $event->type eq Event::Type::KEY_PRESS;
        my $char = $event->payload->char;
        my $code = $event->payload->code;

        if ($code == Event::KeyCode::ESC) {
            $self->{cancelled} = 1;
            $changed = 1;
            next;
        }

        if ($code == Event::KeyCode::ENTER) {
            if ($self->{submit_on_enter}) {
                $self->{submitted} = 1;
                $changed = 1;
            } else {
                $changed = 1 if $self->insert_newline;
            }
            next;
        }

        if ($code == 8 || $code == 127) {
            $changed = 1 if $self->backspace;
            next;
        }
        if ($code == 1) {
            $changed = 1 if $self->move_home;
            next;
        }
        if ($code == 5) {
            $changed = 1 if $self->move_end;
            next;
        }
        if ($code == 2) {
            $changed = 1 if $self->move_left;
            next;
        }
        if ($code == 6) {
            $changed = 1 if $self->move_right;
            next;
        }
        if ($code == 16) {
            $changed = 1 if $self->move_up;
            next;
        }
        if ($code == 14) {
            $changed = 1 if $self->move_down;
            next;
        }
        if ($code == 4) {
            $changed = 1 if $self->delete_forward;
            next;
        }

        next if $code < 32;
        $changed = 1 if $self->insert_char($char);
    }
    $changed;
}

1;

__END__

=head1 NAME

TextBoxInput

=head1 SYNOPSIS

    use TextBoxInput;
    my $tb = TextBoxInput::new(
        -max_w => 20,
        -max_h => 5,
        -material_focus => 'DEFAULT',
        -material_blur => 'DEFAULT',
    );
    $tb->update(@events);

=head1 DESCRIPTION

TextBoxInput is a multiline text editor with a fixed viewport. The
viewport is C<-max_w> by C<-max_h>, with the last column reserved for
a scrollbar. Text wraps at C<max_w - 1>.

=head1 METHODS

=over 4

=item new(%opts)

Creates a text box. Options:

- C<-text> initial content (newlines allowed)
- C<-max_w> viewport width (must be >= 2)
- C<-max_h> viewport height (must be >= 1)
- C<-material_focus> material when focused
- C<-material_blur> material when blurred
- C<-submit_on_enter> if true, Enter sets submitted instead of newline
- C<-cursor> C<[$row, $col]> optional initial cursor

=item update(@events)

Handles key presses. Editing shortcuts:

    Ctrl-B  left
    Ctrl-F  right
    Ctrl-P  up
    Ctrl-N  down
    Ctrl-A  line start
    Ctrl-E  line end
    Ctrl-D  delete forward
    Backspace deletes before cursor
    Enter inserts newline (or submits if enabled)
    Esc sets cancelled

=item render($renderer, $pos_vec, %opts)

Renders the visible rows and scrollbar using focus/blur materials.

=item text

Returns the full text (joined with newlines).

=item display_rows

Returns the rows as rendered (including scrollbar column).

=item scrollbar_rows

Returns scrollbar characters for each visible row.

=item focus / blur

Marks the widget as focused or blurred.

=item clear_flags

Resets submitted/cancelled flags.

=back
