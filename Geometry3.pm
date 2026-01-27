package Geometry3;

use v5.36;
use utf8;
use Carp;
use List::Util;

use lib ".";
use Utils qw(getters);
use Matrix3 qw($EAST);

use overload
    '""' => \&to_str,
    '@{}' => \&to_array,
    ;

getters qw(data points);

sub to_str ($self, $other, $swap = 0) {
    sprintf "Geometry(%d x %d)", $self->rows, $self->cols;
}

sub to_array($self, $other, $swap) {
    $self->data;
}

sub _parse($data) { 
    [
        map { [ split //u, $_] }
        split /\n/, $data
    ];
}

sub from_array(@array) {
    bless {
        data => \@array,
        points => [],
    }, __PACKAGE__;
}

sub from_str($str, %opts) {
    use integer;

    my @geometry;
    my $array = _parse($str);
    my $pos = Matrix3::Vec::from_xy(0, 0);
    my $width = scalar $array->[0]->@*;
    my $T = Matrix3::translate(-$width, -1);
    my %points;
    my $label_text = undef;
    my $label_pos = undef;
    for my $row ($array->@*) {
        for my $col_idx (0 .. $row->$#*) {
            my $col = $row->[$col_idx];
            # . is the alpha char (transparency)
            
            if ($col eq ".") {
                $pos *= $EAST;
                next;
            }

            my $poscpy = $pos->copy;
            if ($col =~ /[\$@]/) {
                $label_text = "$col";
                $label_pos = $poscpy;
                $pos *= $EAST;
                next;
            }

            if ($col =~ /[A-Z]/) {
                $label_text .= $col;
                $pos *= $EAST;
                next;
            } elsif (defined($label_text)) {
                $points{$label_text} = $label_pos;
                $label_text = undef;
                $label_pos = undef;
            }

            push @geometry, [$poscpy, $col];
            $pos *= $EAST;
        }
        $pos *= $T;
    }
    my $self = bless {
        data => \@geometry,
        points => \%points,
    }, __PACKAGE__;
    $self->centerfy_inplace
        if $opts{-centerfy};
    $self;
}

sub copy($self) {
    Geometry3::from_array($self->@*);
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
    Matrix3::Vec::from_xy($self->cols/2, -$self->rows/2);
}

sub mul_inplace($self, $matrix) {
    for ($self->@*) {
        $_->[0] *= $matrix;
    }

    for (values $self->{points}->%*) {
        $_ *= $matrix;
    }
}

sub centerfy_inplace($self) {
    my $center = $self->center;
    $center->mul_scalar_inplace(-1);
    $self->mul_inplace(Matrix3::translate($center->@*));
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

    my $triangle = Geometry3::from_str(<<'EOF', -centerfy => 1);
    ..x..
    .x x.
    xxxxx
    EOF

The '.' are treated as transparent and do not become part of the geometry.
