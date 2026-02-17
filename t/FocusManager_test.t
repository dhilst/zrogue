use v5.36;
use Test::More;

use lib ".";
use FocusManager;
use Event;

{
    package WidgetStub;
    sub new($name) { bless { name => $name, focus => 0, blur => 0, updates => 0 }, __PACKAGE__ }
    sub focus($self) { $self->{focus}++ }
    sub blur($self) { $self->{blur}++ }
    sub update($self, @events) { $self->{updates} += scalar @events; return @events ? 1 : 0; }
    sub focus_count($self) { $self->{focus} }
    sub blur_count($self) { $self->{blur} }
    sub update_count($self) { $self->{updates} }
}

sub key($ch) { Event::key_press($ch) }

subtest 'initial focus' => sub {
    my $w1 = WidgetStub::new('a');
    my $w2 = WidgetStub::new('b');
    my $fm = FocusManager::new([$w1, $w2]);
    is($w1->focus_count, 1, 'first widget focused');
    is($w2->focus_count, 0, 'second not focused');
};

subtest 'cycles on tab' => sub {
    my $w1 = WidgetStub::new('a');
    my $w2 = WidgetStub::new('b');
    my $fm = FocusManager::new([$w1, $w2]);
    my $changed = $fm->update(key("\t"));
    ok($changed, 'update reports change');
    is($w1->blur_count, 1, 'first widget blurred');
    is($w2->focus_count, 1, 'second widget focused');
};

subtest 'custom keybind' => sub {
    my $w1 = WidgetStub::new('a');
    my $w2 = WidgetStub::new('b');
    my $fm = FocusManager::new([$w1, $w2], -key => 'n');
    $fm->update(key('n'));
    is($w1->blur_count, 1, 'blurred on custom key');
    is($w2->focus_count, 1, 'focused on custom key');
};

subtest 'cycle wraps' => sub {
    my $w1 = WidgetStub::new('a');
    my $w2 = WidgetStub::new('b');
    my $fm = FocusManager::new([$w1, $w2], -index => 1);
    $fm->update(key("\t"));
    is($w2->blur_count, 1, 'second blurred');
    is($w1->focus_count, 1, 'wraps to first');
};

subtest 'routes events to current widget' => sub {
    my $w1 = WidgetStub::new('a');
    my $w2 = WidgetStub::new('b');
    my $fm = FocusManager::new([$w1, $w2]);
    my @changed = $fm->update(key('x'));
    is($w1->update_count, 1, 'current widget updated');
    is(scalar @changed, 1, 'changed list contains current');
};

subtest 'add and remove widgets' => sub {
    my $w1 = WidgetStub::new('a');
    my $fm = FocusManager::new([]);
    ok(!defined $fm->current, 'no current when empty');
    ok(!$fm->update(key("\t")), 'no change when empty');

    $fm->add_widget($w1);
    is($w1->focus_count, 1, 'focus on first add');
    is($fm->current, $w1, 'current set');

    my $w2 = WidgetStub::new('b');
    $fm->add_widget($w2);
    $fm->remove_widget($w1);
    is($w1->blur_count, 1, 'removed focused widget blurred');
    is($fm->current, $w2, 'focus moved to next');

    $fm->remove_widget($w2);
    ok(!defined $fm->current, 'empty after removals');
};

done_testing;
