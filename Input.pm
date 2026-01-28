package Input;
use v5.36;

use Carp;
use IO::Select;
use POSIX qw(ICANON ECHO VMIN VTIME TCSANOW);

use lib ".";
use Event;
use Utils qw(getters);

getters qw(select termios orig fd);

sub new() {
    confess "STDIN is not a TTY" unless -t STDIN;

    binmode(STDIN);
    my $fd = fileno(STDIN);

    my $sel = IO::Select->new(\*STDIN);

    # save original terminal state
    my $orig = POSIX::Termios->new;
    $orig->getattr($fd);

    # working copy
    my $termios = POSIX::Termios->new;
    $termios->getattr($fd);

    my $self = bless {
        select  => $sel,
        termios => $termios,
        orig    => $orig,
        fd      => $fd,
    }, __PACKAGE__;

    $self->enable_raw_mode;
    return $self;
}

sub enable_raw_mode($self) {
    my $t  = $self->{termios};

    # disable canonical mode and echo
    $t->setlflag( $t->getlflag & ~(ICANON | ECHO) );

    # non-blocking reads
    $t->setcc(VMIN,  0);
    $t->setcc(VTIME, 0);

    $t->setattr($self->{fd}, TCSANOW);
}

sub poll($self, $timeout) {
    my @events;

    return @events
        unless $self->select->can_read($timeout);

    while (sysread(\*STDIN, my $ch, 1)) {
        push @events, Event::key_press($ch);
    }

    return @events;
}

sub restore_mode($self) {
    $self->{orig}->setattr($self->{fd}, TCSANOW)
        if $self->{orig};
}

sub DESTROY($self) {
    $self->restore_mode;
}

1;
