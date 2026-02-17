package ButtonGroupInput;

use v5.36;
use utf8;
use Carp;

use lib ".";
use Utils qw(getters);
use Event;
use Matrix3;
use ButtonInput;

getters qw(
    buttons
    index
    selected
    submitted
    cancelled
    focused
    key_prev
    key_next
);

sub new(%opts) {
    my $buttons = $opts{-buttons};
    if (defined $buttons) {
        confess "buttons must be arrayref" unless ref($buttons) eq 'ARRAY';
    } else {
        my $labels = $opts{-labels};
        confess "missing -labels" unless defined $labels;
        confess "labels must be arrayref" unless ref($labels) eq 'ARRAY';
        $buttons = [
            map {
                ButtonInput::new(
                    -label => $_,
                    -material_focus => $opts{-material_focus},
                    -material_blur => $opts{-material_blur},
                )
            } $labels->@*
        ];
    }

    my $index = defined $opts{-index} ? int($opts{-index}) : 0;
    $index = 0 if $index < 0;
    $index = $buttons->$#* if $index > $buttons->$#* && $buttons->@*;

    my $self = bless {
        buttons => $buttons,
        index => $buttons->@* ? $index : -1,
        selected => undef,
        submitted => 0,
        cancelled => 0,
        focused => 0,
        key_prev => $opts{-key_prev} // 'k',
        key_next => $opts{-key_next} // 'j',
    }, __PACKAGE__;
    $self->_sync_focus;
    $self;
}

sub clear_flags($self) {
    $self->{submitted} = 0;
    $self->{cancelled} = 0;
    $_->clear_flags for $self->{buttons}->@*;
}

sub _sync_focus($self) {
    return unless $self->{buttons}->@*;
    for my $i (0 .. $self->{buttons}->$#*) {
        if ($self->{focused} && $i == $self->{index}) {
            $self->{buttons}->[$i]->focus;
        } else {
            $self->{buttons}->[$i]->blur;
        }
    }
}

sub focus($self) {
    $self->{focused} = 1;
    $self->_sync_focus;
}

sub blur($self) {
    $self->{focused} = 0;
    $self->_sync_focus;
}

sub move_prev($self) {
    my $count = $self->{buttons}->@*;
    return 0 if $count == 0;
    $self->{index} = ($self->{index} - 1) % $count;
    $self->_sync_focus;
    1;
}

sub move_next($self) {
    my $count = $self->{buttons}->@*;
    return 0 if $count == 0;
    $self->{index} = ($self->{index} + 1) % $count;
    $self->_sync_focus;
    1;
}

sub current_button($self) {
    return undef if $self->{index} < 0;
    $self->{buttons}->[$self->{index}];
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
        if ($char eq $self->{key_prev}) {
            $changed = 1 if $self->move_prev;
            next;
        }
        if ($char eq $self->{key_next}) {
            $changed = 1 if $self->move_next;
            next;
        }
        if ($code == Event::KeyCode::ENTER || $char eq ' ') {
            my $btn = $self->current_button;
            if ($btn) {
                $btn->press;
                $self->{selected} = $self->{index};
                $self->{submitted} = 1;
                $changed = 1;
            }
            next;
        }
    }
    $changed;
}

sub render($self, $renderer, $pos_vec, %opts) {
    my $x = 0;
    for my $btn ($self->{buttons}->@*) {
        my $text = $btn->display_text;
        $btn->render($renderer, $pos_vec + Matrix3::Vec::from_xy($x, 0), %opts);
        $x += length($text) + 1;
    }
}

1;

__END__

=head1 NAME

ButtonGroupInput

=head1 SYNOPSIS

    use ButtonGroupInput;
    my $bg = ButtonGroupInput::new(-labels => [qw(OK Cancel)]);
    $bg->update(@events);

=head1 DESCRIPTION

ButtonGroupInput manages a set of buttons and cycles focus between them.
It exposes a selected index when a button is pressed.

=head1 METHODS

=over 4

=item new(%opts)

Creates a button group. Options:

- C<-labels> arrayref of labels (used to create buttons)
- C<-buttons> arrayref of ButtonInput objects (alternative to labels)
- C<-material_focus> material when focused (for created buttons)
- C<-material_blur> material when blurred (for created buttons)
- C<-index> initial focused index
- C<-key_prev> key to move focus backward (default: C<k>)
- C<-key_next> key to move focus forward (default: C<j>)

=item update(@events)

Handles key presses:

    key_prev / key_next cycle focus
    Enter or Space presses current button
    Esc sets cancelled

=item render($renderer, $pos_vec, %opts)

Renders buttons in a horizontal row with one space between them.

=item focus / blur

Marks the group as focused or blurred and updates the current button.

=item clear_flags

Resets submitted/cancelled flags and clears button flags.

=back
