package Termlib;

use v5.36;
use utf8;
use open ':std', ':encoding(UTF-8)';
no autovivification;

use Data::Dumper;
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
    return if $ENV{SUPPRESS_TERMLIB};
    local $| = 1;
    print $self->term->Tputs("ho", 1);
    print $self->term->Tputs("cl", 1);
}

# We ignore right extra arguments to allow calling
# with homogeneous vectors as $term->write('x', $vec->@*);
sub write($self, $value, $col, $row, @ignored) {
    return if $ENV{SUPPRESS_TERMLIB};
    local $| = 1;
    print $self->term->Tputs("sc", 1);
    print $self->term->Tgoto("cm", $col, $row);
    print $value;
    print $self->term->Tputs("rc", 1);
}

sub write_color($self, $value, $col, $row, $fg = -1, $bg = -1, $attrs = -1) {
    return if $ENV{SUPPRESS_TERMLIB};
    local $| = 1;
    my @sgr_attrs;
    push @sgr_attrs, SGR::attrs($attrs) if $attrs ne -1;
    push @sgr_attrs, SGR::fg($fg) if $fg ne -1;
    push @sgr_attrs, SGR::bg($bg) if $bg ne -1;

    print $self->term->Tputs("sc", 1);
    print $self->term->Tgoto("cm", $col, $row);
    if (@sgr_attrs) {
        print colored($value, @sgr_attrs);
    } else {
        print $value;
    }
    print $self->term->Tputs("rc", 1);
}

sub write_vec($self, $value, $pos_vec) {
    my ($col, $row) = $pos_vec->@*;
    $self->write($value, $col, $row);
}

sub initscr($self, $default_value = ' ') {
    return if $ENV{SUPPRESS_TERMLIB};
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

__END__

=head1 NAME

Termlib

=head1 SYNOPSIS

    use Termlib;
    my $term = Termlib::new();
    $term->initscr;
    $term->write("Hello", 0, 0);

=head1 DESCRIPTION

Termlib wraps Term::Cap and Term::ANSIColor for cursor movement and
colored output. It provides basic terminal screen operations used by
renderers.

=head1 METHODS

=over 4

=item new

Creates a Termlib instance with Term::Cap initialized.

=item rows / cols

Returns terminal dimensions.

=item clear

Clears the terminal and homes the cursor.

=item write($text, $col, $row)

Writes raw text at a position.

=item write_color($text, $col, $row, $fg, $bg, $attrs)

Writes text using 24-bit colors and attributes.

=item write_vec($text, $pos_vec)

Writes at the given Matrix3::Vec.

=item initscr($default_value)

Clears and fills the screen with the given character.

=back
