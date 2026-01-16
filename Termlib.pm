package Termlib;
use v5.36;
use lib ".";
use Utils qw(getters);

getters qw(term);

sub new($cls) {
    bless {
        term => Term::Cap->Tgetent(),
    }, $cls
}

sub rows {
    int(`tput lines`) - 1;
}

sub cols {
    int(`tput cols`) + 1;
}

sub clear($self) {
    print $self->term->Tputs("ho", 1);
    print $self->term->Tputs("cl", 1);
}

# We ignore right extra arguments to allow calling
# with homogeneous vectors as $term->write('x', $vec->@*);
sub write($self, $value, $col, $row, @ignored) {
    print $self->term->Tputs("sc", 1);
    print $self->term->Tgoto("cm", $col, $row);
    print $value;
    print $self->term->Tputs("rc", 1);
}

sub write_vec($self, $value, $pos_vec) {
    my ($col, $row) = $pos_vec->@*;
    $self->write($value, $col, $row);
}

sub initscr($self, $default_value = ' ') {
    $self->clear;
    print join "\n", map { $default_value x ($self->cols - 1) } 0 .. $self->rows - 1;
}

1;
