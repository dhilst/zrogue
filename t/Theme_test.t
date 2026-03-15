use v5.36;
use Test::More;
use Test::Exception;

use lib '.';
use TerminalStyle;
use TerminalBorderStyle;
use Theme;
use File::Temp qw(tempfile);

sub warnings($code) {
    my @warnings;
    local $SIG{__WARN__} = sub ($message) {
        push @warnings, $message;
    };
    $code->();
    return @warnings;
}

{
    package TestMaterialMapper;
    use v5.36;

    sub new($styles, $classes = {}) {
        bless {
            styles => $styles,
            classes => $classes,
        }, __PACKAGE__;
    }

    sub style($self, $material) {
        return $self->lookup($material);
    }

    sub lookup($self, $material) {
        return $self->{styles}{$material};
    }

    sub cache_class($self, $material) {
        return $self->{classes}{$material} // 'STATIC_UNIFORM';
    }

    sub cache_key($self, $dt, $x, $y, $material) {
        return join ':', 'mat', ($dt // ''), ($x // ''), ($y // ''), $material;
    }
}

{
    package TestBorderMapper;
    use v5.36;

    sub new($styles, $classes = {}) {
        bless {
            styles => $styles,
            classes => $classes,
        }, __PACKAGE__;
    }

    sub style($self, $material) {
        return $self->lookup($material);
    }

    sub lookup($self, $material) {
        return $self->{styles}{$material};
    }

    sub cache_class($self, $material) {
        return $self->{classes}{$material} // 'STATIC_UNIFORM';
    }

    sub cache_key($self, $dt, $x, $y, $material, $edge) {
        return join ':', 'border', ($dt // ''), ($x // ''), ($y // ''), $material, $edge;
    }
}

sub build_theme(%opts) {
    my $material_mapper = $opts{material_mapper} // TestMaterialMapper::new({});
    my $border_mapper = $opts{border_mapper} // TestBorderMapper::new({});
    return Theme::new(
        -material_mapper => $material_mapper,
        -border_mapper => $border_mapper,
    );
}

subtest 'constructor validates required mappers' => sub {
    my $material = TestMaterialMapper::new({});
    my $border = TestBorderMapper::new({});

    dies_ok { Theme::new(-border_mapper => $border) } 'missing material mapper dies';
    dies_ok { Theme::new(-material_mapper => $material) } 'missing border mapper dies';
    dies_ok { Theme::new(-material_mapper => bless({}, 'BadMat'), -border_mapper => $border) } 'material mapper must support lookup';
    dies_ok { Theme::new(-material_mapper => $material, -border_mapper => bless({}, 'BadBorder')) } 'border mapper must support lookup';
};

subtest 'delegates successful lookups to mappers' => sub {
    my $material = TerminalStyle::new(-fg => 0xabcdef);
    my $border = TerminalBorderStyle::new(-border => ['1' .. '9']);

    my $theme = build_theme(
        material_mapper => TestMaterialMapper::new({ OK => $material }),
        border_mapper => TestBorderMapper::new({ OK => $border }),
    );

    is($theme->style('OK'), $material, 'material style delegated');
    is($theme->border('OK'), $border, 'border style delegated');
};

subtest 'uses mapper DEFAULT for missing material key and warns once' => sub {
    my $default = TerminalStyle::new(-fg => 0x123456, -attrs => 9);
    my $theme = build_theme(
        material_mapper => TestMaterialMapper::new({ DEFAULT => $default }),
    );

    my @warnings = warnings(sub {
        is($theme->style('MISSING'), $default, 'first fallback returns DEFAULT');
        is($theme->style('MISSING'), $default, 'second fallback still returns DEFAULT');
    });

    is(scalar @warnings, 1, 'warned once');
    like($warnings[0], qr/Missing material key 'MISSING'/, 'warning mentions missing material');
};

subtest 'uses built-in material fallback when DEFAULT is absent' => sub {
    my $theme = build_theme();

    my @warnings = warnings(sub {
        my $style = $theme->style('NOPE');
        isa_ok($style, 'TerminalStyle');
        is_deeply({ %$style }, {
            -fg => 0xffffff,
            -bg => 0x000000,
            -attrs => 0,
        }, 'built-in material fallback');
    });

    is(scalar @warnings, 1, 'warned once for missing material');
};

subtest 'uses mapper DEFAULT for missing border key and warns once' => sub {
    my $default = TerminalBorderStyle::new(
        -fg => 0x010203,
        -bg => 0x040506,
        -attrs => 7,
        -border => ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
    );
    my $theme = build_theme(
        border_mapper => TestBorderMapper::new({ DEFAULT => $default }),
    );

    my @warnings = warnings(sub {
        is($theme->border('MISSING_BORDER'), $default, 'first fallback returns DEFAULT');
        is($theme->border('MISSING_BORDER'), $default, 'second fallback still returns DEFAULT');
    });

    is(scalar @warnings, 1, 'warned once');
    like($warnings[0], qr/Missing border key 'MISSING_BORDER'/, 'warning mentions missing border');
};

subtest 'uses built-in border fallback when DEFAULT is absent' => sub {
    my $theme = build_theme();

    my @warnings = warnings(sub {
        my $style = $theme->border('NOPE');
        isa_ok($style, 'TerminalBorderStyle');
        is($style->fg, 0xffffff, 'default border fg');
        is($style->bg, 0x000000, 'default border bg');
        is($style->attrs, 0, 'default border attrs');
        is_deeply($style->border, ['+', '-', '+', '|', ' ', '|', '+', '-', '+'], 'default border glyphs');
    });

    is(scalar @warnings, 1, 'warned once for missing border');
};

subtest 'delegates cache class lookups' => sub {
    my $theme = build_theme(
        material_mapper => TestMaterialMapper::new({}, { A => 'DYNAMIC_CELLWISE' }),
        border_mapper => TestBorderMapper::new({}, { B => 'STATIC_CELLWISE' }),
    );

    is($theme->material_cache_class('A'), 'DYNAMIC_CELLWISE', 'material cache class delegated');
    is($theme->border_cache_class('B'), 'STATIC_CELLWISE', 'border cache class delegated');
    is($theme->material_cache_key(1, 2, 3, 'A'), 'mat:1:2:3:A', 'material cache key delegated');
    is($theme->border_cache_key(1, 2, 3, 'B', 'TOP'), 'border:1:2:3:B:TOP', 'border cache key delegated');
};

subtest 'from_file loads static theme definitions' => sub {
    my $content = <<'INI'
[material:TITLE]
fg = 0x00ff00
bg = 0
attrs = 1

[material:DEFAULT]
fg = 0x123456

[border:FRAME]
fg = 9
bg = 17
attrs = 0
glyphs = ┌,─,┐,│, ,│,└,─,┘
INI
;

    my ($fh, $path) = tempfile(SUFFIX => '.ini', UNLINK => 1);
    print {$fh} $content;
    close $fh;

    my $theme = Theme::from_file($path);

    is_deeply($theme->style('TITLE')->as_hashref, {
        -fg => 0x00ff00,
        -bg => 0,
        -attrs => 1,
    }, 'material loaded from file');
    is_deeply($theme->style('DEFAULT')->as_hashref, {
        -fg => 0x123456,
    }, 'default material loaded from file');

    my $frame = $theme->border('FRAME');
    isa_ok($frame, 'TerminalBorderStyle');
    is_deeply($frame->border, ['┌', '─', '┐', '│', ' ', '│', '└', '─', '┘'], 'frame border glyphs loaded');
    is($frame->fg, 9, 'frame border fg loaded');
    is($frame->bg, 17, 'frame border bg loaded');
    is($frame->attrs, 0, 'frame border attrs loaded');
};

subtest 'from_file supports inline content mode' => sub {
    my $theme = Theme::from_file('ignored', -content => <<'INI'
[material:ALT]
fg = 255
bg = -1

[border:ALT]
fg = -1
glyphs = +,+,+,+, ,+,+,+,+
INI
);
    is($theme->style('ALT')->fg, 255, 'inline content material loaded');
    is($theme->border('ALT')->bg, -1, 'inline content border loaded');
    is_deeply($theme->border('ALT')->border, ['+', '+', '+', '+', ' ', '+', '+', '+', '+'], 'inline content glyphs loaded');
};

subtest 'from_file fails on schema violations' => sub {
    my $bad_sections = <<'INI'
[unknown:THING]
fg = 1
INI
;

    my ($fh1, $path1) = tempfile(SUFFIX => '.ini', UNLINK => 1);
    print {$fh1} $bad_sections;
    close $fh1;
    dies_ok { Theme::from_file($path1) } 'unknown top-level section dies';

    my $bad_border = <<'INI'
[border:FRAME]
glyphs = +
INI
;

    my ($fh2, $path2) = tempfile(SUFFIX => '.ini', UNLINK => 1);
    print {$fh2} $bad_border;
    close $fh2;
    dies_ok { Theme::from_file($path2) } 'malformed border glyph list dies';
};

done_testing;
