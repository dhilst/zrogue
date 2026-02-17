package CheckboxInput;

use v5.36;
use utf8;
use Carp;

use lib ".";
use Utils qw(getters);
use Event;

getters qw(
    checked
    material_focus
    material_blur
    submitted
    cancelled
    focused
);

sub new(%opts) {
    my $checked = $opts{-checked} // 0;
    bless {
        checked => $checked ? 1 : 0,
        material_focus => $opts{-material_focus},
        material_blur => $opts{-material_blur},
        submitted => 0,
        cancelled => 0,
        focused => 0,
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

sub focus($self) { $self->{focused} = 1; }
sub blur($self) { $self->{focused} = 0; }

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
input. It also exposes submitted/cancelled flags and supports focused
rendering styles.

=head1 METHODS

=over 4

=item new(%opts)

Creates a checkbox. Options:

- C<-checked> initial state
- C<-material_focus> material when focused
- C<-material_blur> material when blurred

=item update(@events)

Handles key presses:

    space or 'x' toggles
    Enter sets submitted
    Esc sets cancelled

=item toggle

Flips the checked state.

=item clear_flags

Resets submitted/cancelled flags.

=item focus / blur

Marks the widget as focused or blurred.

=item render($renderer, $pos_vec, %opts)

Renders the checkbox using focus/blur materials.

=back
