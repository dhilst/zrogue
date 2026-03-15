package ZTUI::MaterialMapper;

use v5.36;
use utf8;
no autovivification;
use Carp qw(confess);
use overload '&{}' => \&as_coderef, fallback => 1;

use ZTUI::TerminalStyle;
use ZTUI::Utils qw(getters);

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
    return $style if ref($style) eq 'ZTUI::TerminalStyle';
    return undef unless ref($style) eq 'HASH';
    return undef unless _valid_style_hash($style);
    return ZTUI::TerminalStyle::new($style->%*);
}

sub style($self, $material) {
    my $style = $self->lookup($material);
    confess "Invalid material $material" if !defined $style;
    return $style;
}

sub cache_class($self, $material) {
    return 'STATIC_UNIFORM';
}

sub cache_key($self, $dt, $x, $y, $material) {
    return $material;
}

sub map($self, $material) {
    $self->style($material);
}

sub as_coderef($self, $other = undef, $swap = undef) {
    sub ($material) { $self->style($material) };
}

sub _valid_style_hash($style) {
    for my $key (keys $style->%*) {
        return 0 unless $key eq '-fg' || $key eq '-bg' || $key eq '-attrs';
    }

    return 0 if exists($style->{-fg}) && !_valid_color($style->{-fg});
    return 0 if exists($style->{-bg}) && !_valid_color($style->{-bg});
    return 0 if exists($style->{-attrs}) && !_valid_integer($style->{-attrs});
    return 1;
}

sub _valid_integer($value) {
    return defined($value) && int($value) == $value;
}

sub _valid_color($value) {
    return 0 unless _valid_integer($value);
    return $value == -1 || ($value >= 0 && $value <= 0xFFFFFF);
}

1;

__END__

=head1 NAME

MaterialMapper

=head1 SYNOPSIS

    use ZTUI::SGR qw(:attrs):
    use ZTUI::MaterialMapper;

    my $mat = ZTUI::MaterialMapper::from_callback(sub ($material) {
        return { -fg => 0xff00ff } if $material eq 'MAGENTA';
        return { -bg => 0x000000, -attrs => ATTR_BOLD } if $material eq 'HIGHLIGHT';
    });

    my $style = $mat->style('MAGENTA');

=head1 DESCRIPTION

MaterialMapper wraps a user-provided callback into a mapping from MATERIAL to STYLE.
STYLE is a hashref that may contain C<-fg>, C<-bg>, and C<-attrs> keys; any of
them may be absent. Unknown keys and undefined materials cause an error.

=head1 METHODS

=over 4

=item from_callback($callback)

Creates a MaterialMapper mapping. The callback is invoked as C<$callback->($material)>
and must return a style hashref, a L<TerminalStyle> object, or C<undef>.

=item style($material)

Returns a L<TerminalStyle> for the given material. If the callback returns
C<undef>, the method throws an error.

=item map($material)

Alias for C<style>.

=back

=head1 OVERLOADS

=over 4

=item &{}

Instances can be called like a coderef: C<$mat->($material)>.

=back
