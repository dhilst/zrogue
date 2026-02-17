use v5.36;
use Test::More;

use lib ".";
use ButtonInput;
use Event;

sub key($ch) { Event::key_press($ch) }

subtest 'press with enter' => sub {
    my $btn = ButtonInput::new(-label => 'OK');
    ok(!$btn->pressed, 'starts unpressed');
    my $changed = $btn->update(key("\n"));
    ok($changed, 'reports change');
    ok($btn->pressed, 'pressed by enter');
};

subtest 'press with space' => sub {
    my $btn = ButtonInput::new(-label => 'OK');
    $btn->update(key(' '));
    ok($btn->pressed, 'pressed by space');
};

subtest 'esc cancels' => sub {
    my $btn = ButtonInput::new(-label => 'OK');
    $btn->update(key(chr(27)));
    ok($btn->cancelled, 'cancelled by esc');
};

subtest 'clear flags' => sub {
    my $btn = ButtonInput::new(-label => 'OK');
    $btn->update(key(' '));
    $btn->update(key(chr(27)));
    $btn->clear_flags;
    ok(!$btn->pressed, 'pressed cleared');
    ok(!$btn->cancelled, 'cancelled cleared');
};

done_testing;
