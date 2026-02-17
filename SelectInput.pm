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
    submitted
    cancelled
);

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

    bless {
        options => $options,
        index => $index,
        selected => $selected,
        submitted => 0,
        cancelled => 0,
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
move the selection and confirm it.

=head1 METHODS

=over 4

=item new(%opts)

Creates a selector. Requires C<-options> arrayref. Optional C<-index>
and C<-selected> set initial positions.

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

=back
