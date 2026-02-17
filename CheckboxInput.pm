package CheckboxInput;

use v5.36;
use utf8;
use Carp;

use lib ".";
use Utils qw(getters);
use Event;

getters qw(
    checked
    material
    submitted
    cancelled
);

sub new(%opts) {
    my $checked = $opts{-checked} // 0;
    bless {
        checked => $checked ? 1 : 0,
        material => $opts{-material},
        submitted => 0,
        cancelled => 0,
    }, __PACKAGE__;
}

sub clear_flags($self) {
    $self->{submitted} = 0;
    $self->{cancelled} = 0;
}

sub toggle($self) {
    $self->{checked} = $self->{checked} ? 0 : 1;
    1;
}

sub display_text($self) {
    $self->{checked} ? '[x]' : '[ ]';
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

        if ($char eq ' ' || $char eq 'x') {
            $changed = 1 if $self->toggle;
        }
    }
    $changed;
}

1;

__END__

=head1 NAME

CheckboxInput

=head1 SYNOPSIS

    use CheckboxInput;
    my $cb = CheckboxInput::new();
    $cb->update(@events);

=head1 DESCRIPTION

CheckboxInput tracks a boolean value that can be toggled with keyboard
input. It also exposes submitted/cancelled flags.

=head1 METHODS

=over 4

=item new(%opts)

Creates a checkbox. Option C<-checked> sets the initial state.

=item update(@events)

Handles key presses:

    space or 'x' toggles
    Enter sets submitted
    Esc sets cancelled

=item toggle

Flips the checked state.

=item clear_flags

Resets submitted/cancelled flags.

=back
