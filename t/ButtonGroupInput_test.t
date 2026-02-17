use v5.36;
use Test::More;

use lib ".";
use ButtonGroupInput;
use Event;

sub key($ch) { Event::key_press($ch) }

subtest 'cycles focus' => sub {
    my $bg = ButtonGroupInput::new(-labels => [qw(OK Cancel)]);
    $bg->focus;
    ok($bg->buttons->[0]->focused, 'first focused');
    $bg->update(key('j'));
    is($bg->index, 1, 'moved to second');
    ok($bg->buttons->[1]->focused, 'second focused');
    $bg->update(key('j'));
    is($bg->index, 0, 'wraps to first');
};

subtest 'press selects' => sub {
    my $bg = ButtonGroupInput::new(-labels => [qw(OK Cancel)]);
    $bg->focus;
    $bg->update(key('j'));
    $bg->update(key("\n"));
    ok($bg->submitted, 'submitted');
    is($bg->selected, 1, 'selected index');
    ok($bg->buttons->[1]->pressed, 'button pressed');
};

subtest 'esc cancels' => sub {
    my $bg = ButtonGroupInput::new(-labels => [qw(OK Cancel)]);
    $bg->update(key(chr(27)));
    ok($bg->cancelled, 'cancelled');
};

done_testing;
