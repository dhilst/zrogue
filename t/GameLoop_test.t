use v5.36;
use Test::More;
use Time::HiRes qw(time);

use FindBin qw($Bin);
use lib "$Bin/../lib";
use ZTUI::GameLoop;

{
    package TestGameLoop::Input {
        use v5.36;
        sub new($class, @events) {
            return bless { events => \@events }, $class;
        }
        sub drain($self) {
            return $self->{events}->@*;
        }
    }

    package TestGameLoop::Renderer {
        use v5.36;
        sub new($class) {
            return bless { flushes => 0 }, $class;
        }
        sub flush($self) {
            $self->{flushes}++;
            return;
        }
    }

    package TestGameLoop::Widget {
        use v5.36;
        sub new($class, @returns) {
            return bless {
                returns => \@returns,
                updates => 0,
                renders => 0,
            }, $class;
        }
        sub update($self, $delta_time, @events) {
            $self->{updates}++;
            return shift($self->{returns}->@*) if $self->{returns}->@*;
            return 1;
        }
        sub render($self, $renderer) {
            $self->{renders}++;
            return;
        }
    }
}

sub mk_loop(@widgets) {
    my $renderer = TestGameLoop::Renderer->new();
    my $loop = bless {
        resized => 0,
        renderer => $renderer,
        input => TestGameLoop::Input->new(),
        localtime => time(),
        widgets => \@widgets,
    }, 'ZTUI::GameLoop';
    return ($loop, $renderer);
}

subtest 'update -1 skips render for that widget only' => sub {
    my $w_skip = TestGameLoop::Widget->new(-1);
    my $w_draw = TestGameLoop::Widget->new(1);
    my ($loop, $renderer) = mk_loop($w_skip, $w_draw);

    my $stopped = 0;
    $loop->_tick(sub { $stopped++ });

    is($w_skip->{renders}, 0, 'widget returning -1 is not rendered this frame');
    is($w_draw->{renders}, 1, 'other widget still renders');
    is($renderer->{flushes}, 1, 'frame flushes when at least one widget renders');
    is($stopped, 0, 'loop keeps running');
};

subtest 'all widgets skipped means no flush' => sub {
    my $w1 = TestGameLoop::Widget->new(-1);
    my $w2 = TestGameLoop::Widget->new(-1);
    my ($loop, $renderer) = mk_loop($w1, $w2);

    $loop->_tick(sub { });

    is($w1->{renders}, 0, 'first widget skipped');
    is($w2->{renders}, 0, 'second widget skipped');
    is($renderer->{flushes}, 0, 'no flush when nothing rendered');
};

subtest 'false update still stops loop' => sub {
    my $w_stop = TestGameLoop::Widget->new(0);
    my $w_skip = TestGameLoop::Widget->new(-1);
    my ($loop, $renderer) = mk_loop($w_stop, $w_skip);

    my $stopped = 0;
    $loop->_tick(sub { $stopped++ });

    is($stopped, 1, 'false update stops loop');
    is($w_stop->{renders}, 1, 'stopping widget still renders for this frame');
    is($w_skip->{renders}, 0, 'skipped widget does not render');
    is($renderer->{flushes}, 1, 'flush occurs because one widget rendered');
};

done_testing;
