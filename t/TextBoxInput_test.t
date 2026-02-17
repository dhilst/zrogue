use v5.36;
use Test::More;

use lib ".";
use TextBoxInput;
use Event;

sub key($ch) { Event::key_press($ch) }

subtest 'wraps at width' => sub {
    my $tb = TextBoxInput::new(-max_w => 6, -max_h => 3);
    $tb->update(map { key($_) } split //, 'abcdef');
    is_deeply($tb->lines, ['abcde', 'f'], 'wrapped lines');
    is($tb->cursor_row, 1, 'cursor row moved');
    is($tb->cursor_col, 1, 'cursor col moved');
};

subtest 'newline splits lines' => sub {
    my $tb = TextBoxInput::new(-max_w => 6, -max_h => 3);
    $tb->update(key('a'), key("\n"), key('b'));
    is($tb->text, "a\nb", 'text contains newline');
    is_deeply($tb->lines, ['a', 'b'], 'lines split');
};

subtest 'scroll follows cursor' => sub {
    my $tb = TextBoxInput::new(-max_w => 6, -max_h => 2);
    $tb->update(key('a'), key("\n"), key('b'), key("\n"), key('c'));
    is($tb->scroll_top, 1, 'scroll_top moves down');
};

subtest 'scrollbar shows thumb' => sub {
    my $tb = TextBoxInput::new(-max_w => 6, -max_h => 2);
    $tb->update(key('a'), key("\n"), key('b'), key("\n"), key('c'));
    is_deeply([$tb->scrollbar_rows], ['|', '#'], 'scrollbar rows');
};

done_testing;
