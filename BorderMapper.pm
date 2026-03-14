package BorderMapper;

use v5.36;
use utf8;
no autovivification;
use Carp qw(confess);
use overload '&{}' => \&as_coderef, fallback => 1;

use lib ".";
use TerminalBorderStyle;
use Utils qw(getters);

getters qw(mapper);

sub from_callback($mapper) {
    confess "missing mapper" unless defined $mapper;
    confess "mapper must be a coderef" unless ref($mapper) eq 'CODE';
    bless {
        mapper => $mapper,
    }, __PACKAGE__;
}

sub lookup($self, $material) {
    my $style = $self->{mapper}->($material);
    return undef if !defined $style;
    return $style if ref($style) eq 'TerminalBorderStyle';

    my $border = _normalize_border($style);
    return undef unless defined $border;
    return TerminalBorderStyle::new(-border => $border);
}

sub style($self, $material) {
    my $style = $self->lookup($material);
    confess "Invalid border material $material" if !defined $style;
    return $style;
}

sub cache_class($self, $material) {
    return 'STATIC_UNIFORM';
}

sub cache_key($self, $dt, $x, $y, $material, $edge) {
    return join ':', $material, $edge;
}

sub map($self, $material) {
    $self->style($material);
}

sub as_coderef($self, $other = undef, $swap = undef) {
    sub ($material) { $self->style($material) };
}

sub _normalize_border($style) {
    my @rows;

    if (!ref($style)) {
        @rows = split /\n/, $style;
    } elsif (ref($style) eq 'ARRAY') {
        if (@$style == 3 && !grep { ref($_) } @$style) {
            @rows = @$style;
        } elsif (@$style == 3 && !grep { ref($_) ne 'ARRAY' } @$style) {
            my @norm;
            for my $row (@$style) {
                return undef unless @$row == 3;
                push @norm, map { "$_" } @$row;
            }
            return \@norm;
        } else {
            return undef;
        }
    } else {
        return undef;
    }

    return undef unless @rows == 3;

    my @norm;
    for my $row (@rows) {
        my @chars = split //u, "$row";
        return undef unless @chars == 3;
        push @norm, @chars;
    }
    return \@norm;
}

1;
