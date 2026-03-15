package Theme;

use v5.36;
use utf8;
use Carp qw(confess);
use lib ".";
use IniFile;
use MaterialMapper;
use BorderMapper;
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

sub from_file($path_or_content, %opts) {
    my $source = $opts{-content} // $path_or_content;
    confess "missing path or content" unless defined $source;

    my $strict = exists($opts{-strict}) ? $opts{-strict} : 1;
    confess "-strict must be 0 or 1" unless $strict == 0 || $strict == 1;

    my $ini = IniFile::new(-strict => $strict);
    my $data;

    if (defined $opts{-content}) {
        $data = $ini->parse(-content => $source);
    }
    elsif (-f $source) {
        $data = $ini->parse_file($source);
    }
    else {
        $data = $ini->parse(-content => $source);
    }

    $ini->validate(
        $data,
        -strict_sections => $strict,
        -strict_keys => $strict,
        -sections => [
            { name => 'theme.metadata' },
            {
                prefix => 'material:',
                keys => {
                    fg    => sub ($value, $section, $key) {
                        return _looks_like_integer($value);
                    },
                    bg    => sub ($value, $section, $key) {
                        return _looks_like_integer($value);
                    },
                    attrs => sub ($value, $section, $key) {
                        return _looks_like_integer($value);
                    },
                },
            },
            {
                prefix => 'border:',
                keys => {
                    fg        => sub ($value, $section, $key) {
                        return _looks_like_integer($value);
                    },
                    bg        => sub ($value, $section, $key) {
                        return _looks_like_integer($value);
                    },
                    attrs     => sub ($value, $section, $key) {
                        return _looks_like_integer($value);
                    },
                    glyphs    => sub ($value, $section, $key) {
                        return _looks_like_glyphs($value);
                    },
                    top_left  => sub ($value, $section, $key) {
                        return _looks_like_border_glyph($value);
                    },
                    top      => sub ($value, $section, $key) {
                        return _looks_like_border_glyph($value);
                    },
                    top_right => sub ($value, $section, $key) {
                        return _looks_like_border_glyph($value);
                    },
                    left     => sub ($value, $section, $key) {
                        return _looks_like_border_glyph($value);
                    },
                    center   => sub ($value, $section, $key) {
                        return _looks_like_border_glyph($value);
                    },
                    right    => sub ($value, $section, $key) {
                        return _looks_like_border_glyph($value);
                    },
                    bottom_left => sub ($value, $section, $key) {
                        return _looks_like_border_glyph($value);
                    },
                    bottom   => sub ($value, $section, $key) {
                        return _looks_like_border_glyph($value);
                    },
                    bottom_right => sub ($value, $section, $key) {
                        return _looks_like_border_glyph($value);
                    },
                },
            },
        ],
    );

    my %material_map;
    my %border_map;

    for my $section (keys $data->%*) {
        my $payload = $data->{$section};
        if ($section =~ /^material:(.+)$/) {
            my $material = $1;
            confess "Missing material name in section '$section'" if !defined($material) || $material eq '';

            my %style_args;
            if (exists $payload->{fg}) {
                my $fg = _coerce_int($payload->{fg}, $section, 'fg');
                $style_args{-fg} = $fg if defined $fg;
            }
            if (exists $payload->{bg}) {
                my $bg = _coerce_int($payload->{bg}, $section, 'bg');
                $style_args{-bg} = $bg if defined $bg;
            }
            if (exists $payload->{attrs}) {
                my $attrs = _coerce_int($payload->{attrs}, $section, 'attrs');
                $style_args{-attrs} = $attrs if defined $attrs;
            }

            $material_map{$material} = TerminalStyle::new(%style_args);
            next;
        }

        if ($section =~ /^border:(.+)$/) {
            my $border_material = $1;
            confess "Missing border material in section '$section'" if !defined($border_material) || $border_material eq '';

            my %style_args;
            if (exists $payload->{fg}) {
                my $fg = _coerce_int($payload->{fg}, $section, 'fg');
                $style_args{-fg} = $fg if defined $fg;
            }
            if (exists $payload->{bg}) {
                my $bg = _coerce_int($payload->{bg}, $section, 'bg');
                $style_args{-bg} = $bg if defined $bg;
            }
            if (exists $payload->{attrs}) {
                my $attrs = _coerce_int($payload->{attrs}, $section, 'attrs');
                $style_args{-attrs} = $attrs if defined $attrs;
            }

            my @named_glyph_fields = qw(
                top_left
                top
                top_right
                left
                center
                right
                bottom_left
                bottom
                bottom_right
            );

            if (exists $payload->{glyphs}) {
                $style_args{-border} = _parse_glyphs($payload->{glyphs}, $section);
            }
            else {
                my @present = grep { exists $payload->{$_} } @named_glyph_fields;
                if (@present) {
                    confess "Border section '$section' must define all 9 border glyph names" if @present != 9;
                    my @glyphs = map { _coerce_border_glyph($payload->{$_}, $section, $_) } @named_glyph_fields;
                    $style_args{-border} = \@glyphs;
                }
            }

            $border_map{$border_material} = TerminalBorderStyle::new(%style_args);
            next;
        }

        next if $section eq 'theme.metadata';
        confess "Unknown section '$section'";
    }

    my $material_mapper = MaterialMapper::from_callback(sub ($material) {
        return $material_map{$material};
    });
    my $border_mapper = BorderMapper::from_callback(sub ($border_material) {
        return $border_map{$border_material};
    });

    return Theme::new(
        -material_mapper => $material_mapper,
        -border_mapper => $border_mapper,
    );
}

sub _coerce_int($value, $section, $key) {
    if (!defined $value) {
        confess "Missing value for '$key' in section '$section'";
    }

    my $text = "$value";
    if ($text =~ /^\s*0x([0-9A-Fa-f]+)\s*$/) {
        return hex $1;
    }
    if ($text =~ /^\s*([+-]?\d+)\s*$/) {
        return int($1);
    }

    confess "Invalid integer '$value' for '$key' in section '$section'";
}

sub _looks_like_integer($value) {
    return 0 unless defined $value;
    return 1 if "$value" =~ /^\s*[+-]?\d+\s*$/;
    return 1 if "$value" =~ /^\s*0x[0-9A-Fa-f]+\s*$/;
    return 0;
}

sub _looks_like_border_glyph($value) {
    return 0 unless defined $value;
    my $glyph = _normalize_border_glyph($value);
    return 0 unless defined $glyph;
    my @chars = split //, $glyph;
    return scalar(@chars) == 1;
}

sub _looks_like_glyphs($value) {
    return 0 unless defined $value;
    my @glyphs = split /,/, "$value";
    return 0 if scalar(@glyphs) != 9;
    for my $glyph (@glyphs) {
        return 0 unless _looks_like_border_glyph($glyph);
    }
    return 1;
}

sub _coerce_border_glyph($value, $section, $key) {
    if (!defined $value) {
        confess "Missing border glyph '$key' in section '$section'";
    }

    my $glyph = _normalize_border_glyph($value);
    if (!defined $glyph) {
        confess "Border glyph '$key' must be a valid utf-8 character in section '$section'";
    }

    if ($glyph eq ' ') {
        return ' ';
    }

    my @chars = split //, $glyph;
    confess "Border glyph '$key' must be a single-character glyph in section '$section'"
        unless @chars == 1;
    return $chars[0];
}

sub _normalize_border_glyph($value) {
    my $glyph = "$value";
    return ' ' if $glyph =~ /^\s+$/;
    $glyph =~ s/^\s+//;
    $glyph =~ s/\s+$//;
    return $glyph if utf8::is_utf8($glyph);

    my $decoded = $glyph;
    return undef unless utf8::decode($decoded);
    return $decoded;
}

sub _parse_glyphs($value, $section) {
    my @glyphs = split /,/, "$value";
    confess "Border section '$section' must define 9 comma-separated glyphs"
        unless @glyphs == 9;
    my @coerced;
    for my $glyph (@glyphs) {
        push @coerced, _coerce_border_glyph($glyph, $section, 'glyphs');
    }
    return \@coerced;
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

=item from_file($path_or_content, %opts)

Creates a theme from static INI data. C<$path_or_content> may be a filesystem
path or a direct content string. Use C<-content> explicitly to force content mode.
Optional C<-strict> sets INI schema strictness (defaults to true).

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
