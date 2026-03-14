package Theme;

use v5.36;
use utf8;
use Carp qw(confess);

use lib ".";
use TerminalStyle;
use TerminalBorderStyle;

sub new(%opts) {
    my $material_mapper = $opts{'-material_mapper'};
    my $border_mapper = $opts{'-border_mapper'};

    confess "missing -material_mapper" unless defined $material_mapper;
    confess "missing -border_mapper" unless defined $border_mapper;
    confess "-material_mapper must support lookup()"
        unless ref($material_mapper) && $material_mapper->can('lookup');
    confess "-border_mapper must support lookup()"
        unless ref($border_mapper) && $border_mapper->can('lookup');

    my $self = {
        material_mapper => $material_mapper,
        border_mapper => $border_mapper,
        warned_materials => {},
        warned_borders => {},
        fallback_material_style => TerminalStyle::new(
            -fg => 0xffffff,
            -bg => 0x000000,
            -attrs => 0,
        ),
        fallback_border_style => TerminalBorderStyle::new(
            -fg => 0xffffff,
            -bg => 0x000000,
            -attrs => 0,
            -border => ['+', '-', '+', '|', ' ', '|', '+', '-', '+'],
        ),
    };
    bless $self, __PACKAGE__;
}

sub style($self, $material, %context) {
    return $self->_resolve_material($material);
}

sub border($self, $border_material, %context) {
    return $self->_resolve_border($border_material);
}

sub material_cache_class($self, $material) {
    my $mapper = $self->{material_mapper};
    confess "material mapper must support cache_class()"
        unless $mapper->can('cache_class');
    return $mapper->cache_class($material);
}

sub material_cache_key($self, $dt, $x, $y, $material) {
    my $mapper = $self->{material_mapper};
    confess "material mapper must support cache_key()"
        unless $mapper->can('cache_key');
    return $mapper->cache_key($dt, $x, $y, $material);
}

sub border_cache_class($self, $border_material) {
    my $mapper = $self->{border_mapper};
    confess "border mapper must support cache_class()"
        unless $mapper->can('cache_class');
    return $mapper->cache_class($border_material);
}

sub border_cache_key($self, $dt, $x, $y, $border_material, $edge) {
    my $mapper = $self->{border_mapper};
    confess "border mapper must support cache_key()"
        unless $mapper->can('cache_key');
    return $mapper->cache_key($dt, $x, $y, $border_material, $edge);
}

sub _resolve_material($self, $material) {
    my $mapper = $self->{material_mapper};
    my $style = $mapper->lookup($material);
    return $style if defined $style && ref($style) eq 'TerminalStyle';

    return $self->_material_default($material);
}

sub _resolve_border($self, $border_material) {
    my $mapper = $self->{border_mapper};
    my $style = $mapper->lookup($border_material);
    return $style if defined $style && ref($style) eq 'TerminalBorderStyle';

    return $self->_border_default($border_material);
}

sub _material_default($self, $material) {
    $self->_warn_missing_once(material => $material);
    my $mapper = $self->{material_mapper};
    my $default = $mapper->lookup('DEFAULT');
    return $default if defined $default && ref($default) eq 'TerminalStyle';
    return $self->{fallback_material_style};
}

sub _border_default($self, $material) {
    $self->_warn_missing_once(border => $material);
    my $mapper = $self->{border_mapper};
    my $default = $mapper->lookup('DEFAULT');
    return $default if defined $default && ref($default) eq 'TerminalBorderStyle';
    return $self->{fallback_border_style};
}

sub _warn_missing_once($self, $type, $key) {
    my $bucket = $type eq 'material'
        ? $self->{warned_materials}
        : $self->{warned_borders};
    return if $bucket->{$key}++;
    warn "Missing $type key '$key', falling back to DEFAULT\n";
}

1;

__END__

=head1 NAME

Theme

=head1 SYNOPSIS

    use Theme;

    my $theme = Theme::new(
        -material_mapper => $material_mapper,
        -border_mapper => $border_mapper,
    );

    my $style = $theme->style('PANEL_BG');
    my $border = $theme->border('PANEL_BORDER');

=head1 DESCRIPTION

Theme is a facade over material and border mappers. It centralizes fallback
behavior, warning deduplication, and cache delegation for renderer-side
style resolution.

=head1 METHODS

=over 4

=item new(%opts)

Constructs a theme from C<-material_mapper> and C<-border_mapper>.

=item style($material, %context)

Returns a L<TerminalStyle> for the requested material, using C<DEFAULT> or a
built-in fallback if the mapper lookup fails.

=item border($border_material, %context)

Returns a L<TerminalBorderStyle> for the requested border material, using
C<DEFAULT> or a built-in fallback if the mapper lookup fails.

=item material_cache_class($material)

=item border_cache_class($border_material)

=item material_cache_key($dt, $x, $y, $material)

=item border_cache_key($dt, $x, $y, $border_material, $edge)

Delegates cache-class and cache-key lookup to the underlying mappers.

=back

=cut
