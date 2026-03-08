package BorderMapper;

use v5.36;
use utf8;
no autovivification;
use Carp;
use overload '&{}' => \&as_coderef, fallback => 1;

use lib ".";
use Utils qw(getters);

getters qw(mapper);

sub from_callback($mapper) {
    confess "missing mapper" unless defined $mapper;
    confess "mapper must be a coderef" unless ref($mapper) eq 'CODE';
    bless {
        mapper => $mapper,
    }, __PACKAGE__;
}

sub style($self, $material) {
    my $style = $self->{mapper}->($material);
    confess "Invalid border material $material" if !defined $style;
    return _normalize_style($style);
}

sub map($self, $material) {
    $self->style($material);
}

sub as_coderef($self, $other = undef, $swap = undef) {
    sub ($material) { $self->style($material) };
}

sub _normalize_style($style) {
    my @rows;

    if (!ref($style)) {
        @rows = split /\n/, $style;
    } elsif (ref($style) eq 'ARRAY') {
        if (@$style == 3 && !grep { ref($_) } @$style) {
            @rows = @$style;
        } elsif (@$style == 3 && !grep { ref($_) ne 'ARRAY' } @$style) {
            my @norm;
            for my $row (@$style) {
                confess "border row must have 3 columns"
                    unless @$row == 3;
                push @norm, [map { "$_" } @$row];
            }
            return \@norm;
        } else {
            confess "border style must be 3 rows";
        }
    } else {
        confess "border style must be string or arrayref";
    }

    confess "border style must be 3 rows"
        unless @rows == 3;

    my @norm;
    for my $row (@rows) {
        my @chars = split //u, "$row";
        confess "border row must have exactly 3 chars"
            unless @chars == 3;
        push @norm, \@chars;
    }
    return \@norm;
}

1;
