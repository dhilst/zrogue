package Geometry;

use v5.36;
use Carp;

use lib ".";
use Utils qw(getters);
use Matrix qw($EAST);

use overload
    '""' => \&to_str,
    '@{}' => \&to_array,
    ;

getters qw(data);

sub to_str ($self, $other, $swap = 0) {
    sprintf "Geometry(%d x %d)", $self->rows, $self->cols;
}

sub to_array($self, $other, $swap) {
    $self->data;
}

sub _parse($data) { 
    [
        map { [ split //, $_] }
        split /\n/, $data
    ];
}

sub from_array(@array) {
    bless {
        data => \@array
    }, __PACKAGE__;
}

sub from_str($str, %opts) {
    my @geometry;
    my $array = _parse($str);
    my $pos = Vec->new(0, 0, 1);
    my $width = scalar $array->[0]->@*;
    for my $row ($array->@*) {
        for my $col ($row->@*) {
            push @geometry, [$pos, $col]
                   if $col ne ".";
            $pos *= $EAST;
        }
        $pos *= Matrix::translate(-$width, -1);
    }
    my $self = bless {
        data => \@geometry
    }, __PACKAGE__;
    $self->centerfy_inplace
        if $opts{-centerfy};
    $self;
}

sub copy($self) {
    Geometry::from_array($self->@*);
}

sub max_row($self) {
    return $self->{_max_row_cache}
        if exists $self->{_max_row_cache};

    $self->{_max_row_cache} = 
        List::Util::max
        map { abs $_->[0]->[1] }
        $self->@*;
    $self->{_max_row_cache};
}

sub max_col($self) {
    return $self->{_max_col_cache}
        if exists $self->{_max_col_cache};

    $self->{_max_col_cache} = 
        List::Util::max
        map { $_->[0]->[0] }
        $self->@*;
    $self->{_max_col_cache};
}

sub rows($self) { $self->max_row + 1; }
sub cols($self) { $self->max_col + 1; }

sub center($self) {
    use integer;
    Vec->new($self->cols/2, -$self->rows/2, 1);
}

sub mul_inplace($self, $matrix) {
    for ($self->@*) {
        $_->[0] *= $matrix;
    }
}

sub centerfy_inplace($self) {
    $self->mul_inplace(Matrix::translate_vec(-$self->center));
}

1;

__END__

=head1 NAME

Geometry

=head1 SYNOPSIS

Geometry is defined as a set of pairs (coordinate, values) which
represent objects that can be rendered in an 2d grid space. Origin
is set to top left corner with Y increasing UP by default. To
have origin at the center of the object use '-centerfy => 1' in
from_str constructor;

This constructor expect a string like this:

    my $triangle = Geometry::from_str(<<'EOF', -centerfy => 1);
    ..x..
    .x x.
    xxxxx
    EOF

The '.' are treated as transparent and do not become part of the geometry.
