package Vec;

use v5.36;
use Carp;
use List::Util;
use Math::BigInt;
use Scalar::Util qw(looks_like_number);
use Exporter qw(import);

use overload 
    '""' => \&to_str,
    '+'  => 'add',
    '-'  => 'sub',
    '*'  => 'mul',
    'neg'=> 'neg',
    fallback => 1;

sub new($cls, @values) {
    bless \@values, $cls;
}

sub combine :prototype(&$$) ($block, $self, $other) {
    confess "invalid vec combination: $self x $other",
        unless scalar $self->@* == scalar $other->@*;

    my @values =
        map { $block->($_->@*) }
        List::Util::zip $self, $other;

    Vec->new(@values);
}

sub to_str($self, @ignored) {
    sprintf "(%s)", join ",", $self->@*;
}

sub add($self, $other, $swap = 0) {
    return $other->add($self, 0)
        if $swap;

    Vec::combine { List::Util::sum(@_) } $self, $other;
}

sub neg($self, @ignored) {
    Vec->new(map { - $_ } $self->@*);
}

sub sub($self, $other, $swap = 0) {
    return $other->sub($self, 0)
        if $swap;

    Vec::combine { List::Util::sum(@_) } 
    $self, $other->neg;
}

sub mul($self, $other, $swap = 0) {
    return $other * $self if $swap;
    return $self->scale($other)
        if looks_like_number($other);
    return $other->mul_vec($self)
        if ref($other) eq 'Matrix';
    confess "invalid operation $self * $other";
}

sub scale($self, $scalar, $swap = 0) {
    confess "cannot commute vector mul"
        unless $swap;

    Vec->new(map { $_ * $scalar } $self->@*);
}

sub length($self) {
    sqrt(List::Util::sum map { $_ ** 2 } $self->@*);
}

sub direction_sqrt($self) {
    my $l = $self->length;
    Vec->new(map { $_ / $l } $self->@*);
}

sub direction_gcd($self) {
    my $g = List::Util::reduce {
        Math::BigInt::bgcd($a, abs $b)
    } 0, $self->@*;

    confess "0 GCD" if $g == 0;
    Vec->new(map { $_ / $g } $self->@*);
}

sub direction_chebyshev($self) {
    Vec->new(map { $_ <=> 0 } $self->@*);
}

sub dot($self, $other) {
    confess "dimension mismatch"
        unless  $self->@* == $other->@*;

    List::Util::sum
    map { List::Util::product($_->@*) }
    List::Util::zip($self, $other);
}

sub dim($self) {
    scalar $self->@*;
}

sub copy($self) {
    Vec->new($self->@*);
}

1;
