package TextInput;

use v5.36;
use utf8;
use Carp;

use lib ".";
use Utils qw(getters);
use Event;

getters qw(
    text
    cursor
    material
    max_len
    submitted
    cancelled
);

sub max_len_from_bounds($anchor, $maxx) {
    return undef if !defined $anchor || !defined $maxx;
    my $x = ref($anchor) && $anchor->can('x') ? $anchor->x : $anchor;
    my $max = $maxx - $x - 1;
    return undef if $max < 0;
    $max;
}

sub new(%opts) {
    my $text = $opts{-text} // '';
    my $max_len = $opts{-max_len};
    if (!defined $max_len && defined $opts{-max_from}) {
        my ($anchor, $maxx) = $opts{-max_from}->@*;
        $max_len = max_len_from_bounds($anchor, $maxx);
    }
    if (defined $max_len && length($text) > $max_len) {
        $text = substr($text, 0, $max_len);
    }
    my $cursor = defined $opts{-cursor} ? int($opts{-cursor}) : length($text);
    confess "cursor out of range"
        if $cursor < 0 || $cursor > length($text);

    bless {
        text => $text,
        cursor => $cursor,
        material => $opts{-material},
        max_len => $max_len,
        submitted => 0,
        cancelled => 0,
    }, __PACKAGE__;
}

sub clear_flags($self) {
    $self->{submitted} = 0;
    $self->{cancelled} = 0;
}

sub set_text($self, $text) {
    $text //= '';
    if (defined $self->{max_len} && length($text) > $self->{max_len}) {
        $text = substr($text, 0, $self->{max_len});
    }
    my $changed = $text ne $self->{text};
    $self->{text} = $text;
    $self->{cursor} = length($text) if $self->{cursor} > length($text);
    return $changed;
}

sub clear($self) {
    my $changed = $self->{text} ne '';
    $self->{text} = '';
    $self->{cursor} = 0;
    return $changed;
}

sub display_text($self) {
    my $text = $self->{text} // '';
    my $max_len = $self->{max_len};
    return $text if !defined $max_len;
    $text = substr($text, 0, $max_len) if length($text) > $max_len;
    my $pad = $max_len - length($text);
    $text .= ' ' x $pad if $pad > 0;
    $text;
}

sub render($self, $renderer, $pos_vec, %opts) {
    my %style;
    if (defined $self->{material}) {
        my $mapper = $renderer->mapper;
        if (ref($mapper) && $mapper->can('style')) {
            %style = $mapper->style($self->{material})->%*;
        } else {
            %style = $mapper->($self->{material})->%*;
        }
    }
    $renderer->render_text($pos_vec, $self->display_text, %style, %opts);
}

sub insert($self, $text) {
    return 0 unless defined $text && length($text) > 0;
    my $max_len = $self->{max_len};
    if (defined $max_len) {
        my $available = $max_len - length($self->{text});
        return 0 if $available <= 0;
        $text = substr($text, 0, $available) if length($text) > $available;
    }
    my $cur = $self->{cursor};
    substr($self->{text}, $cur, 0, $text);
    $self->{cursor} += length($text);
    return length($text) > 0;
}

sub backspace($self) {
    return 0 if $self->{cursor} <= 0;
    my $idx = $self->{cursor} - 1;
    substr($self->{text}, $idx, 1, '');
    $self->{cursor} = $idx;
    1;
}

sub delete_forward($self) {
    return 0 if $self->{cursor} >= length($self->{text});
    substr($self->{text}, $self->{cursor}, 1, '');
    1;
}

sub move_left($self) {
    return 0 if $self->{cursor} <= 0;
    $self->{cursor}--;
    1;
}

sub move_right($self) {
    return 0 if $self->{cursor} >= length($self->{text});
    $self->{cursor}++;
    1;
}

sub move_home($self) {
    return 0 if $self->{cursor} == 0;
    $self->{cursor} = 0;
    1;
}

sub move_end($self) {
    my $end = length($self->{text});
    return 0 if $self->{cursor} == $end;
    $self->{cursor} = $end;
    1;
}

sub update($self, @events) {
    my $changed = 0;
    for my $event (@events) {
        next unless $event->type eq Event::Type::KEY_PRESS;
        my $char = $event->payload->char;
        my $code = $event->payload->code;

        if ($code == Event::KeyCode::ENTER) {
            $self->{submitted} = 1;
            $changed = 1;
            next;
        }
        if ($code == Event::KeyCode::ESC) {
            $self->{cancelled} = 1;
            $changed = 1;
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
        if ($code == 4) {
            $changed = 1 if $self->delete_forward;
            next;
        }

        next if $code < 32;
        $changed = 1 if $self->insert($char);
    }
    $changed;
}

1;
