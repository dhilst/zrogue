use v5.36;
use Test::More;

use lib ".";
use SelectInput;
use Event;

sub key($ch) { Event::key_press($ch) }

subtest 'navigation wraps' => sub {
    my $sel = SelectInput::new(-options => [qw(a b c)]);
    is($sel->index, 0, 'starts at 0');
    $sel->update(key('k'));
    is($sel->index, 2, 'wraps to last');
    $sel->update(key('j'));
    is($sel->index, 0, 'wraps to first');
};

subtest 'enter selects current' => sub {
    my $sel = SelectInput::new(-options => [qw(a b c)]);
    $sel->update(key('j'));
    $sel->update(key("\n"));
    is($sel->selected, 1, 'selected index updated');
    ok($sel->submitted, 'enter sets submitted');
};

subtest 'esc cancels' => sub {
    my $sel = SelectInput::new(-options => [qw(a b c)]);
    $sel->update(key(chr(27)));
    ok($sel->cancelled, 'esc sets cancelled');
};

done_testing;
