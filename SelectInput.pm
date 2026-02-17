package SelectInput;

use v5.36;
use utf8;
use Carp;

use lib ".";
use Utils qw(getters);
use Event;

getters qw(
    options
    index
    selected
    max_len
    material_focus
    material_blur
    submitted
    cancelled
    focused
);

sub max_len_from_bounds($anchor, $maxx) {
    return undef if !defined $anchor || !defined $maxx;
    my $x = ref($anchor) && $anchor->can('x') ? $anchor->x : $anchor;
    my $max = $maxx - $x - 1;
    return undef if $max < 0;
    $max;
}

sub new(%opts) {
    my $options = $opts{-options};
    confess "missing options" unless defined $options;
    confess "options must be arrayref" unless ref($options) eq 'ARRAY';
    confess "options cannot be empty" unless $options->@*;

    my $index = defined $opts{-index} ? int($opts{-index}) : 0;
    confess "index out of range"
        if $index < 0 || $index > $options->$#*;
    my $selected = defined $opts{-selected} ? int($opts{-selected}) : $index;
    confess "selected out of range"
        if $selected < 0 || $selected > $options->$#*;
    my $max_len = $opts{-max_len};
    if (!defined $max_len && defined $opts{-max_from}) {
        my ($anchor, $maxx) = $opts{-max_from}->@*;
        $max_len = max_len_from_bounds($anchor, $maxx);
    }

    bless {
        options => $options,
        index => $index,
        selected => $selected,
        max_len => $max_len,
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

sub move_prev($self) {
    my $count = $self->{options}->@*;
    return 0 if $count == 0;
    $self->{index} = ($self->{index} - 1) % $count;
    1;
}

sub move_next($self) {
    my $count = $self->{options}->@*;
    return 0 if $count == 0;
    $self->{index} = ($self->{index} + 1) % $count;
    1;
}

sub display_text($self) {
    my $options = $self->{options};
    my $text = $options->[ $self->{index} ];
    my $max_len = $self->{max_len};
    return $text if !defined $max_len;
    $text = substr($text, 0, $max_len) if length($text) > $max_len;
    my $pad = $max_len - length($text);
    $text .= ' ' x $pad if $pad > 0;
    $text;
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
            $self->{selected} = $self->{index};
            $self->{submitted} = 1;
            $changed = 1;
            next;
        }
        if ($code == Event::KeyCode::ESC) {
            $self->{cancelled} = 1;
            $changed = 1;
            next;
        }

        if ($char eq 'k') {
            $changed = 1 if $self->move_prev;
        } elsif ($char eq 'j') {
            $changed = 1 if $self->move_next;
        }
    }
    $changed;
}

1;

__END__

=head1 NAME

SelectInput

=head1 SYNOPSIS

    use SelectInput;
    my $sel = SelectInput::new(-options => [qw(one two three)]);
    $sel->update(@events);

=head1 DESCRIPTION

SelectInput keeps a list of options and a current index. The user can
move the selection and confirm it. It also supports focused rendering
styles.

=head1 METHODS

=over 4

=item new(%opts)

Creates a selector. Requires C<-options> arrayref. Optional C<-index>
and C<-selected> set initial positions. Options:

- C<-max_len> maximum display width
- C<-max_from> C<[$anchor, $maxx]> helper to compute max length
- C<-material_focus> material when focused
- C<-material_blur> material when blurred

=item update(@events)

Handles key presses:

    'k' moves up
    'j' moves down
    Enter selects current index and sets submitted
    Esc sets cancelled

=item move_prev

Moves selection up (wraps).

=item move_next

Moves selection down (wraps).

=item clear_flags

Resets submitted/cancelled flags.

=item focus / blur

Marks the widget as focused or blurred.

=item render($renderer, $pos_vec, %opts)

Renders the current option using focus/blur materials.

=back
