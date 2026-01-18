package Matrix;

use v5.36;
use Scalar::Util qw(looks_like_number);
use List::Util;
use Data::Dumper;
use Carp;
use Data::Dumper;
use Exporter qw(import);

use lib ".";
use Vec;
use Utils qw(aref);

use overload
    '""' => \&to_str,
    '*' => \&mul_dispatch,
    ;

our @EXPORT_OK = qw($NORTH $SOUTH $WEST $EAST);

sub new($cls, @rows) {
    bless [ map { Vec->new($_->@*) } @rows ], $cls;
}

sub from_str($str) {
    my @rows =
        map [ grep { looks_like_number $_ }
              split /\s+/, $_ ],
        split /\n/, $str;
    Matrix->new(@rows);
}

sub to_str($self, @ignored) {
    my sub format_row(@row) {
        sprintf "|%s|", join " ", map { sprintf "%2d", $_ } @row;
    }

    join "\n", map { format_row($_->@*) } $self->@*;
}

sub rows($self) {
    scalar $self->@*;
}

sub cols($self) {
    scalar $self->[0]->@*;
}

sub dim($self) {
    sprintf "%2d x %2d", $self->rows, $self->cols;
}

sub mul_dispatch($self, $other, $swap = 0) {
    return $other * $self if $swap;
    return $self->mul_scalar($other)
        if looks_like_number($other);
    return $self->mul_mat($other)
        if ref($other) eq 'Matrix';
    return $self->mul_vec($other)
        if ref($other) eq 'Vec';

    confess "Invalid other: $other";
}

sub mul_vec($self, $vec) {
    confess "dimension mismatch $self x $vec"
        unless $self->cols == $vec->dim;
    my @out;
    for my $row ($self->@*) {
        my @sum;
        for my $col (0 .. $row->$#*) {
            my $v = $vec->[$col];
            my $x = $row->[$col];
            push @sum, $x * $v;
        }
        push @out, List::Util::sum(@sum);
    }
    Vec->new(@out);
}

sub mul_mat($self, $mat) {
    confess "dim mismatch"
        unless $self->cols == $mat->rows;
    my @rows;
    for my $i (0 .. $self->rows - 1) {
        my @row;
        my $a_row = $self->row($i);
        for my $j (0 .. $mat->cols - 1) {
            my $b_col = $mat->column($j);
            push @row, $a_row->dot($b_col);
        }
        push @rows, \@row;
    }
    Matrix->new(@rows);
}

sub row($self, $row) {
    confess "invalid row $row"
        unless 0 <= $row && $row < $self->rows;
    $self->[$row];
}

sub column($self, $col) {
    confess "invalid col $col"
        unless 0 <= $col && $col < $self->cols;
    my @column;
    for ($self->@*) {
        push @column, $_->[$col];
    }
    Vec->new(@column);
}


sub translate($dx, $dy) {
    Matrix::from_str(<<"EOF");
1 0 $dx
0 1 $dy
0 0 1
EOF
}

sub translate_vec($vec) {
    my ($dx, $dy) = $vec->@*;
    translate($dx, $dy);
}

sub rot($deg) {
    confess "invalid deg $deg"
        unless $deg =~ /^(?:0|90|180|270)$/;
    state %ROTS = (
        0 => Matrix::from_str(<<'EOF'),
1  0  0
0  1  0
0  0  1
EOF
        90 => Matrix::from_str(<<'EOF'),
0 -1  0
1  0  0
0  0  1
EOF
        180 => Matrix::from_str(<<'EOF'),
-1  0  0
 0 -1  0
 0  0  1
EOF
        270 => Matrix::from_str(<<'EOF')
 0  1  0
-1  0  0
 0  0  1
EOF
    );
    $ROTS{$deg}
}

sub reflect_x() {
    state $m = Matrix::from_str(<<'EOF');
 1  0  0
 0 -1  0
 0  0  1
EOF
    $m;
}

sub reflect_y() {
    state $m = Matrix::from_str(<<'EOF');
-1  0  0
 0  1  0
 0  0  1
EOF
    $m;
}

sub map :prototype(&$) ($block, $self) {
    my @rows;
    for my $row ($self->@*) {
        push @rows, [ map { $block->($_) } $row->@* ];
    }
    Matrix->new(@rows);
}

sub int($self) {
    Matrix::map { int($_) } $self;
}

sub mul_scalar($self, $scalar) {
    Matrix::map { $_ * $scalar } $self;
}

our $NORTH = Matrix::translate(0, 1);
our $SOUTH = Matrix::translate(0, -1);
our $WEST  = Matrix::translate(-1, 0);
our $EAST  = Matrix::translate(1, 0);

1;
