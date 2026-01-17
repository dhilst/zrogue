package Matrix;

use v5.36;
use Scalar::Util qw(looks_like_number);
use List::Util;
use Data::Dumper;
use Carp;
use Data::Dumper;

use lib ".";
use Vec;
use Utils qw(aref);

use overload
    '""' => \&to_str,
    '*' => \&mul_dispatch,
    ;

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

sub max_row($self) {
    scalar $self->@*;
}

sub max_col($self) {
    scalar $self->[0]->@*;
}

sub dim($self) {
    sprintf "%2d x %2d", $self->max_row, $self->max_col;
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
        unless $self->max_col == $vec->dim;
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
        unless $self->max_col == $mat->max_row;
    my @rows;
    for my $i (0 .. $self->max_row - 1) {
        my @row;
        my $a_row = $self->row($i);
        for my $j (0 .. $mat->max_col - 1) {
            my $b_col = $mat->column($j);
            push @row, $a_row->dot($b_col);
        }
        push @rows, \@row;
    }
    Matrix->new(@rows);
}

sub row($self, $row) {
    confess "invalid row $row"
        unless 0 <= $row && $row < $self->max_row;
    $self->[$row];
}

sub column($self, $col) {
    confess "invalid col $col"
        unless 0 <= $col && $col < $self->max_col;
    my @column;
    for ($self->@*) {
        push @column, $_->[$col];
    }
    Vec->new(@column);
}


sub translate($dx, $dy) {
    my $m = Matrix::from_str(<<"EOF");
1 0 $dx
0 1 $dy
0 0 1
EOF
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

1;
