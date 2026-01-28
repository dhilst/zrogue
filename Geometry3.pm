package Geometry3;

use v5.36;
use utf8;
use Carp;
use List::Util;

use lib ".";
use Utils qw(getters);
use Matrix3 qw($EAST);
use Viewport;

use overload
    '""' => \&to_str,
    '@{}' => \&to_array,
    ;

getters qw(data points regions);

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

    $opts{-centerfy} //= 0;
    $opts{-bg} //= ' ';

    my $bg = $opts{-bg};
    my @geometry;
    my $array = _parse($str);
    my $pos = Matrix3::Vec::from_xy(0, 0);
    my $width = scalar $array->[0]->@*;
    my $T = Matrix3::translate(-$width, -1);
    my %points;
    my %regions;
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

            if ($col =~ /[\$@]/) {
                # we hit a @ or $
                $label_text = $col;
                $label_pos = $pos->copy;
                push @geometry, [$pos->copy, $bg];
                $pos *= $EAST;
                next;
            }

            if ($col =~ /[A-Z]/ && defined $label_text) {
                # building the label text
                $label_text .= $col;
                push @geometry, [$pos->copy, $bg];
                $pos *= $EAST;
                next;
            } elsif (defined $label_text) {
                # finished parsing the label text
                my $key = substr $label_text, 1;
                if ($label_text =~ /^@/) {
                    # we just parsed a region label (@)
                    if (exists $regions{$key}) {
                        # and it is the closing @ tag
                        my $label_pos = $regions{$key};
                        my $h = abs($label_pos->y - $pos->y) + 1;
                        my $w = abs($label_pos->x - $pos->x);
                        $regions{$key} = Viewport::from_pos_hw($label_pos, $h, $w);
                    } else {
                        # it is the opening @ tag
                        $regions{$key} = $label_pos;
                    }
                } else {
                    # we just parsed a point ($)
                    $points{$key} = $label_pos;
                }

                $label_text = undef;
                $label_pos = undef;
            }

            $label_text = undef;
            $label_pos = undef;
            push @geometry, [$pos->copy, $col];
            $pos *= $EAST;
        }
        $pos *= $T;
    }
    my $self = bless {
        data => \@geometry,
        points => \%points,
        regions => \%regions,
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

    for (values $self->{regions}->%*) {
        $_->move($matrix);
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
