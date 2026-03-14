package GameLoop {
    use v5.36;

    BEGIN {
        # GameLoop uses AnyEvent as the API and EV as the backend.
        # Keep this here so AnyEvent backend detection sees it at load time.
        $ENV{PERL_ANYEVENT_MODEL} //= 'EV';
    }

    use AnyEvent;
    use AnyEvent::Impl::EV ();
    use Carp;
    use Time::HiRes qw(time);

    use lib ".";
    use Input;
    use Matrix3;
    use Renderers;
    use Termlib;

    sub new($theme, @widgets) {
        confess "missing theme" unless defined $theme;
        confess "missing widgets" unless @widgets;

        bless {
            blank => ' ',
            frame_interval => 1 / 60,
            input => Input::new(),
            localtime => time,
            theme => $theme,
            renderer => undef,
            resized => 1,
            term => Termlib::new(),
            anyevent_watchers => [],
            widgets => \@widgets,
        }, __PACKAGE__;
    }

    sub rebuild_renderer($self) {
        my $cols = $self->{term}->cols;
        my $rows = $self->{term}->rows;
        my $renderer = Renderers::DoubleBuffering::new(
            terminal_space($cols, $rows),
            $rows,
            $cols - 1,
            $self->{theme},
            $self->{blank},
        );
        $renderer->initscr();
        $self->{renderer} = $renderer;
    }

    sub terminal_space($cols, $rows) {
        Matrix3::translate(($cols - 1) / 2, $rows / 2)->mul_mat_inplace($Matrix3::REFLECT_X);
    }

    sub _bootstrap_anyevent_with_ev() {
        AnyEvent::detect();
        my $model = do {
            no warnings 'once';
            $AnyEvent::MODEL // '';
        };
        carp "GameLoop expected AnyEvent::Impl::EV backend, got: "
            . ($model eq '' ? '<unset>' : $model)
            if $model ne 'AnyEvent::Impl::EV';
    }

    sub _tick($self, $stop_cb) {
        if ($self->{resized} || !defined $self->{renderer}) {
            $self->rebuild_renderer();
            $self->{resized} = 0;
        }

        my $now = time;
        my $delta_time = $now - $self->{localtime};
        $self->{localtime} = $now;

        my @events = $self->{input}->drain();
        my $keep_running = 1;
        my @skip_render;
        for my $idx (0 .. $#{$self->{widgets}}) {
            my $widget = $self->{widgets}->[$idx];
            my $keep = $widget->update($delta_time, @events);

            # -1 means "do not render this widget for this frame".
            $skip_render[$idx] = (defined($keep) && !ref($keep) && $keep == -1) ? 1 : 0;

            if (defined($keep) && !$keep) {
                $keep_running = 0;
            }
        }

        my $rendered = 0;
        for my $idx (0 .. $#{$self->{widgets}}) {
            next if $skip_render[$idx];
            my $widget = $self->{widgets}->[$idx];
            $widget->render($self->{renderer});
            $rendered = 1;
        }
        $self->{renderer}->flush() if $rendered;

        $stop_cb->() unless $keep_running;
    }

    sub run($self) {
        _bootstrap_anyevent_with_ev();
        local $SIG{WINCH} = sub { $self->{resized} = 1; };
        my $cv = AnyEvent->condvar;

        my $stop = sub {
            $self->{anyevent_watchers} = [];
            $cv->send;
        };
        my $io_w = AnyEvent->io(
            fh => \*STDIN,
            poll => 'r',
            cb => sub { $self->{input}->pump_ready() },
        );
        my $timer_w = AnyEvent->timer(
            after => 0,
            interval => $self->{frame_interval},
            cb => sub { $self->_tick($stop) },
        );

        $self->{anyevent_watchers} = [$io_w, $timer_w];
        $cv->recv;
    }
}

1;
