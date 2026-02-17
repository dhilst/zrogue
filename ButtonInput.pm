package ButtonInput;

use v5.36;
use utf8;
use Carp;

use lib ".";
use Utils qw(getters);
use Event;

getters qw(
    label
    material_focus
    material_blur
    pressed
    cancelled
    focused
);

sub new(%opts) {
    my $label = defined $opts{-label} ? $opts{-label} : 'OK';
    confess "label must be defined" unless defined $label;
    bless {
        label => $label,
        material_focus => $opts{-material_focus},
        material_blur => $opts{-material_blur},
        pressed => 0,
        cancelled => 0,
        focused => 0,
    }, __PACKAGE__;
}

sub clear_flags($self) {
    $self->{pressed} = 0;
    $self->{cancelled} = 0;
}

sub press($self) {
    $self->{pressed} = 1;
    1;
}

sub display_text($self) {
    '[ ' . $self->{label} . ' ]';
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

        if ($code == Event::KeyCode::ENTER || $char eq ' ') {
            $changed = 1 if $self->press;
            next;
        }
        if ($code == Event::KeyCode::ESC) {
            $self->{cancelled} = 1;
            $changed = 1;
            next;
        }
    }
    $changed;
}

1;

__END__

=head1 NAME

ButtonInput

=head1 SYNOPSIS

    use ButtonInput;
    my $btn = ButtonInput::new(-label => 'OK');
    $btn->update(@events);

=head1 DESCRIPTION

ButtonInput represents a clickable button. It tracks a pressed flag and
supports focus/blur rendering styles.

=head1 METHODS

=over 4

=item new(%opts)

Creates a button. Options:

- C<-label> button label (default: C<OK>)
- C<-material_focus> material when focused
- C<-material_blur> material when blurred

=item update(@events)

Handles key presses:

    Enter or Space sets pressed
    Esc sets cancelled

=item press

Sets pressed to true.

=item clear_flags

Resets pressed/cancelled flags.

=item focus / blur

Marks the button as focused or blurred.

=item render($renderer, $pos_vec, %opts)

Renders the button using focus/blur materials.

=back
