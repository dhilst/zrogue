use v5.36;
use Test::More;

use lib ".";
use TextInput;
use Event;

sub key($ch) { Event::key_press($ch) }

subtest 'inserts characters' => sub {
    my $ti = TextInput::new();
    my $changed = $ti->update(
        key('a'),
        key('b'),
        key('c'),
    );
    ok($changed, 'reports change');
    is($ti->text, 'abc', 'text updated');
    is($ti->cursor, 3, 'cursor at end');
};

subtest 'backspace removes before cursor' => sub {
    my $ti = TextInput::new(-text => 'abc');
    $ti->update(key("\x7f"));
    is($ti->text, 'ab', 'backspace removed last char');
    is($ti->cursor, 2, 'cursor moved left');
};

subtest 'cursor movement and insert' => sub {
    my $ti = TextInput::new(-text => 'abcd');
    $ti->update(key("\cB")); # ctrl-b: left
    $ti->update(key("\cB")); # ctrl-b: left
    $ti->update(key('X'));
    is($ti->text, 'abXcd', 'insert in middle');
    is($ti->cursor, 3, 'cursor after insert');
};

subtest 'max_len limits input' => sub {
    my $ti = TextInput::new(-max_len => 2);
    $ti->update(key('a'), key('b'), key('c'));
    is($ti->text, 'ab', 'clamped to max_len');
    is($ti->cursor, 2, 'cursor at max');
};

subtest 'enter and esc set flags' => sub {
    my $ti = TextInput::new();
    $ti->update(key("\n"));
    ok($ti->submitted, 'enter sets submitted');
    $ti->update(key(chr(27)));
    ok($ti->cancelled, 'esc sets cancelled');
};

done_testing;
