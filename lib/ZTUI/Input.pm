package ZTUI::Input;
use v5.36;

use Carp;
use Errno qw(EAGAIN EWOULDBLOCK EINTR);
use IO::Select;
use POSIX qw(ICANON ECHO VMIN VTIME TCSANOW);

use ZTUI::Event;
use ZTUI::UTF8Buffer;
use ZTUI::Utils qw(getters);

getters qw(select termios orig fd utf8buf queue);

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
        queue   => [],
        utf8buf => ZTUI::UTF8Buffer::new(),
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

sub _read_events($self) {
    my @events;
    my @chars;

    while (1) {
        my $n = sysread(\*STDIN, my $chunk, 1024);
        if (!defined $n) {
            last if $!{EAGAIN} || $!{EWOULDBLOCK} || $!{EINTR};
            last;
        }
        last if $n == 0;
        push @chars, $self->{utf8buf}->push_bytes($chunk);
    }
    push @events, map { ZTUI::Event::key_press($_) } @chars;
    return @events;
}

sub pump($self, $timeout = 0) {
    return 0 unless $self->select->can_read($timeout);
    my @events = $self->_read_events();
    push $self->{queue}->@*, @events;
    return scalar @events;
}

sub pump_ready($self) {
    my @events = $self->_read_events();
    push $self->{queue}->@*, @events;
    return scalar @events;
}

sub drain($self) {
    my @events = $self->{queue}->@*;
    $self->{queue} = [];
    return @events;
}

sub poll($self, $timeout) {
    $self->pump($timeout);
    return $self->drain();
}

sub restore_mode($self) {
    $self->{orig}->setattr($self->{fd}, TCSANOW)
        if $self->{orig};
}

sub DESTROY($self) {
    $self->restore_mode;
}

1;

__END__

=head1 NAME

Input

=head1 SYNOPSIS

    use ZTUI::Input;
    my $inp = ZTUI::Input::new();
    my @events = $inp->poll(0.01);

=head1 DESCRIPTION

Input configures the terminal in raw mode, reads bytes from STDIN, and
returns key press events. It uses UTF8Buffer to decode UTF-8 sequences
into characters before generating events.

=head1 METHODS

=over 4

=item new

Creates a new Input handler and switches the terminal to raw mode.

=item poll($timeout)

Returns a list of Event objects read within the given timeout (in seconds).

=item enable_raw_mode

Sets non-canonical, no-echo input mode.

=item restore_mode

Restores the original terminal settings.

=back
