package Termlib;

use v5.36;
use utf8;
use open ':std', ':encoding(UTF-8)';

use Term::Cap;
use Term::ANSIColor qw(colored);

use lib ".";
use Utils qw(getters);
use SGR qw(:attrs);

getters qw(term);

sub new() {
    bless {
        term => Term::Cap->Tgetent(),
    }, __PACKAGE__;
}

sub rows {
    int(`tput lines`);
}

sub cols {
    int(`tput cols`) + 1;
}

sub clear($self) {
    local $| = 1;
    print $self->term->Tputs("ho", 1);
    print $self->term->Tputs("cl", 1);
}

# We ignore right extra arguments to allow calling
# with homogeneous vectors as $term->write('x', $vec->@*);
sub write($self, $value, $col, $row, @ignored) {
    local $| = 1;
    print $self->term->Tputs("sc", 1);
    print $self->term->Tgoto("cm", $col, $row);
    print $value;
    print $self->term->Tputs("rc", 1);
}

sub write_color($self, $value, $col, $row, $fg = undef, $bg = undef, $attrs = undef) {
    local $| = 1;
    print $self->term->Tputs("sc", 1);
    print $self->term->Tgoto("cm", $col, $row);
    my @sgr_attrs;
    push @sgr_attrs, SGR::attrs($attrs) if defined $attrs;
    push @sgr_attrs, SGR::fg($fg) if defined $fg;
    push @sgr_attrs, SGR::bg($bg) if defined $bg;
    print colored($value, @sgr_attrs);
    print $self->term->Tputs("rc", 1);
}

sub write_vec($self, $value, $pos_vec) {
    my ($col, $row) = $pos_vec->@*;
    $self->write($value, $col, $row);
}

sub initscr($self, $default_value = ' ') {
    local $| = 1;
    $self->clear;
    print join "\n", map { $default_value x ($self->cols - 1) } 0 .. $self->rows - 1;
}

sub _rbg($prefix, $color) {
    sprintf "%sr%dg%db%d",
        $prefix,
        ($color >> 16),
        ($color >> 8 & 0xff),
        ($color & 0xff),

}

sub to_sgr($text, $fg32, $bg32, @attrs) {
    my $bg = _rgb("on_", $bg32);
    my $fg = _rgb("", $fg32);
    colored($text, [@attrs, $fg, $bg]);
}


1;
