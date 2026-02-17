package CheckboxInput;

use v5.36;
use utf8;
use Carp;

use lib ".";
use Utils qw(getters);
use Event;

getters qw(
    checked
    submitted
    cancelled
);

sub new(%opts) {
    my $checked = $opts{-checked} // 0;
    bless {
        checked => $checked ? 1 : 0,
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
