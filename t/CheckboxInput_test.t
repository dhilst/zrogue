use v5.36;
use Test::More;

use lib ".";
use CheckboxInput;
use Event;

sub key($ch) { Event::key_press($ch) }

subtest 'toggles with space' => sub {
    my $cb = CheckboxInput::new();
    ok(!$cb->checked, 'starts unchecked');
    my $changed = $cb->update(key(' '));
    ok($changed, 'reports change');
    ok($cb->checked, 'checked after space');
};

subtest 'toggle with x' => sub {
    my $cb = CheckboxInput::new(-checked => 1);
    $cb->update(key('x'));
    ok(!$cb->checked, 'unchecked after x');
};

subtest 'enter and esc set flags' => sub {
    my $cb = CheckboxInput::new();
    $cb->update(key("\n"));
    ok($cb->submitted, 'enter sets submitted');
    $cb->update(key(chr(27)));
    ok($cb->cancelled, 'esc sets cancelled');
};

done_testing;
