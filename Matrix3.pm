use v5.36;
use utf8;

package Matrix3::Vec {
    use overload
        '""' => \&to_str,
        'eq' => \&eq
        ;

    sub to_str($self, $other = undef, $swap = undef) {
        sprintf "[%2d, %2d]", $self->@*;
    }

    sub from_xy($x, $y) {
        bless [$x, $y], __PACKAGE__;
    }

    sub mul_mat_inplace($self, $matrix, $swap = undef) {
        my ($a, $b, $c, $d, $dx, $dy) = $matrix->@*;
        my ($x, $y) = $self->@*;
        $self->[0] = $a * $x + $b * $y + $dx;
        $self->[1] = $c * $x + $d * $y + $dy;
        $self;
    }

    sub mul_scalar_inplace($self, $scalar, $swap = undef) {
        $self->[0] *= $scalar;
        $self->[1] *= $scalar;
        $self;
    }

    sub eq($self, $other, $swap = undef) {
        my ($x1, $y1) = $self->@*;
        my ($x2, $y2) = $other->@*;
        $x1 == $x2 && $y1 == $y2;
    }

    sub copy($self) {
        Matrix3::Vec::from_xy($self->@*);
    }
}

package Matrix3;
use v5.36;
use utf8;
use Exporter qw(import);


use lib ".";
use Utils qw(getters);

our @EXPORT_OK = qw(
    $ID
    $ROT0
    $ROT90
    $ROT180
    $ROT270
    $NORTH
    $SOUTH
    $WEST
    $EAST
    $REFLECT_X
    $REFLECT_Y
);

getters qw(data);

use overload
    '@{}' => \&data,
    '*=' => \&mul_mat_inplace,
    ;

# Constructs the Matrix
# |$a  $b  $tx|
# |$c  $d  $ty|
# | 0   0   1 |
sub from_rows(
    $a, $b, $tx,
    $c, $d, $ty
) {
    bless { 
        data => [$a, $b, $c, $d, $tx, $ty],
    } , __PACKAGE__;
}

sub copy($self) {
    my ($a, $b, $c, $d, $dx, $dy) = $self->@*;
    Matrix3::from_rows(
        $a, $b, $dx,
        $c, $d, $dy
    );
}

sub eq($self, $other, $swap = undef) {
    my ($a1,$b1,$c1,$d1,$dx1,$dy1) = @{ $self->{data} };
    my ($a2,$b2,$c2,$d2,$dx2,$dy2) = @{ $other->{data} };
    $a1  == $a2 &&
    $b1  == $b2 &&
    $c1  == $c2 &&
    $d1  == $d2 &&
    $dx1 == $dx2 &&
    $dy1 == $dy2;
}

sub mul_mat_inplace ($self, $other, $swap = 0) {
    my ($a1,$b1,$c1,$d1,$dx1,$dy1) = @{ $self->{data} };
    my ($a2,$b2,$c2,$d2,$dx2,$dy2) = @{ $other->{data} };

    @{ $self->{data} } = (
        $a1*$a2  + $b1*$c2,           # a
        $a1*$b2  + $b1*$d2,           # b
        $c1*$a2  + $d1*$c2,           # c
        $c1*$b2  + $d1*$d2,           # d
        $a1*$dx2 + $b1*$dy2 + $dx1,   # dx
        $c1*$dx2 + $d1*$dy2 + $dy1,   # dy
    );

    return $self;
}


sub translate($dx, $dy) {
    Matrix3::from_rows(
        1, 0, $dx,
        0, 1, $dy
    );
}

our $ID = Matrix3::from_rows(
    1,  0,  0,
    0,  1,  0,
);

our $ROT0 = $ID;

our $ROT90 = Matrix3::from_rows(
    0, -1,  0,
    1,  0,  0,
);

our $ROT180 = Matrix3::from_rows(
   -1,  0,  0,
    0, -1,  0,
);

our $ROT270 = Matrix3::from_rows(
    0,  1,  0,
   -1,  0,  0,
);

our $NORTH = Matrix3::translate(0, 1);
our $SOUTH = Matrix3::translate(0, -1);
our $WEST  = Matrix3::translate(-1, 0);
our $EAST  = Matrix3::translate(1, 0);

our $REFLECT_X = Matrix3::from_rows(
    1,  0,  0,
    0, -1,  0,
);
our $REFLECT_Y = Matrix3::from_rows(
    -1,  0, 0,
     0,  1, 0,
);


1;

__END__

=head1 NAME

Matrix3 

=head1 SYNOPSIS

Matrix3 represents 3d matrix for rigid motions, it 
is designed to avoid implicit allocations. User should
allocate a matrix and use inplace operations to reuse
the matrix memory during operations. There is no non-inplace
methods.
