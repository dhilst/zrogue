package FocusManager;

use v5.36;
use utf8;
use Carp;
use Scalar::Util qw(refaddr);

use lib ".";
use Utils qw(getters);
use Event;

getters qw(
    widgets
    index
    key
);

sub new($widgets, %opts) {
    confess "missing widgets" unless defined $widgets;
    confess "widgets must be arrayref" unless ref($widgets) eq 'ARRAY';
    my $key = $opts{-key} // "\t";
    my $index = defined $opts{-index} ? int($opts{-index}) : 0;
    if ($widgets->@* && ($index < 0 || $index > $widgets->$#*)) {
        confess "index out of range";
    }

    my $self = bless {
        widgets => $widgets,
        index => $widgets->@* ? $index : -1,
        key => $key,
    }, __PACKAGE__;
    $self->{widgets}->[$self->{index}]->focus if $self->{index} >= 0;
    $self;
}

sub current($self) {
    return undef if $self->{index} < 0;
    $self->{widgets}->[$self->{index}];
}

sub cycle($self, $delta = 1) {
    my $count = $self->{widgets}->@*;
    return undef if $count == 0;
    if ($self->{index} < 0) {
        $self->{index} = 0;
        my $cur = $self->{widgets}->[$self->{index}];
        $cur->focus if $cur;
        return $cur;
    }
    my $old = $self->{widgets}->[$self->{index}];
    $self->{index} = ($self->{index} + $delta) % $count;
    my $new = $self->{widgets}->[$self->{index}];
    $old->blur if $old;
    $new->focus if $new;
    $new;
}

sub update($self, @events) {
    my @changed;
    my %seen;
    my $mark = sub ($widget) {
        return if !defined $widget;
        my $id = refaddr($widget);
        return if $seen{$id}++;
        push @changed, $widget;
    };
    my $current = $self->current;
    my @pending;
    for my $event (@events) {
        next unless $event->type eq Event::Type::KEY_PRESS;
        my $char = $event->payload->char;
        if ($char eq $self->{key}) {
            if ($current && @pending) {
                $mark->($current) if $current->update(@pending);
                @pending = ();
            }
            my $old = $current;
            my $new = $self->cycle(1);
            $mark->($old);
            $mark->($new);
            $current = $self->current;
            next;
        }
        push @pending, $event;
    }
    if ($current) {
        $mark->($current) if $current->update(@pending);
    }
    return wantarray ? @changed : scalar @changed;
}

sub add_widget($self, $widget) {
    confess "missing widget" unless defined $widget;
    push $self->{widgets}->@*, $widget;
    if ($self->{index} < 0) {
        $self->{index} = 0;
        $widget->focus;
    }
}

sub remove_widget($self, $widget) {
    my $widgets = $self->{widgets};
    return if $widgets->@* == 0;
    my $idx = -1;
    for my $i (0 .. $widgets->$#*) {
        if (ref($widgets->[$i]) && ref($widget)) {
            if (refaddr($widgets->[$i]) == refaddr($widget)) {
                $idx = $i;
                last;
            }
            next;
        }
        if ($widgets->[$i] eq $widget) {
            $idx = $i;
            last;
        }
    }
    return if $idx < 0;

    my $old = $widgets->[$idx];
    my $was_current = $idx == $self->{index};
    $old->blur if $was_current;

    splice $widgets->@*, $idx, 1;
    if ($widgets->@* == 0) {
        $self->{index} = -1;
        return;
    }

    if ($was_current) {
        my $new_idx = $idx % $widgets->@*;
        $self->{index} = $new_idx;
        $widgets->[$new_idx]->focus;
    } elsif ($idx < $self->{index}) {
        $self->{index}--;
    }
}

1;

__END__

=head1 NAME

FocusManager

=head1 SYNOPSIS

    use FocusManager;
    my $fm = FocusManager::new(\@widgets);
    $fm->update(@events);

=head1 DESCRIPTION

FocusManager cycles focus across a list of widgets. Each widget must
implement C<focus> and C<blur>. By default the focus key is TAB.

=head1 METHODS

=over 4

=item new($widgets, %opts)

Creates a focus manager for the given widget arrayref. Options:

- C<-key> key used for cycling focus (default: TAB)
- C<-index> initial focused index (default: 0)
An empty widget list is allowed; focus will be unset.

=item update(@events)

Processes events, advances focus when the cycle key is pressed, and
forwards non-cycle events to the focused widget's C<update>.
In list context returns widgets that should be re-rendered; in scalar
context returns the count.

=item add_widget($widget)

Adds a widget to the manager. If the list was empty, the new widget
becomes focused.

=item remove_widget($widget)

Removes a widget. If it was focused, focus moves to the next widget.
If the last widget is removed, focus becomes empty.

=item cycle($delta)

Moves focus by C<$delta> positions.

=item current

Returns the currently focused widget.

=back
