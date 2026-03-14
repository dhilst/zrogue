package LayoutTheme;
use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";

use BorderMapper;
use MaterialMapper;
use TerminalBorderStyle;
use TerminalStyle;
use Theme;

sub build_theme() {
    my $material_mapper = MaterialMapper::from_callback(sub ($material) {
        state %styles = (
            DEFAULT => TerminalStyle::new(-fg => 0xd7e3ea, -bg => 0x081018, -attrs => 0),
            BACKDROP => TerminalStyle::new(-fg => -1, -bg => 0x081018, -attrs => 0),
            PANEL => TerminalStyle::new(-fg => 0xd7e3ea, -bg => 0x10202c, -attrs => 0),
            PANEL_ALT => TerminalStyle::new(-fg => 0xd7e3ea, -bg => 0x162834, -attrs => 0),
            PANEL_SOFT => TerminalStyle::new(-fg => 0xd7e3ea, -bg => 0x122430, -attrs => 0),
            TITLE => TerminalStyle::new(-fg => 0xf0f6fa, -bg => 0x10202c, -attrs => 0),
            TEXT => TerminalStyle::new(-fg => 0xd7e3ea, -bg => 0x10202c, -attrs => 0),
            TEXT_ALT => TerminalStyle::new(-fg => 0xc5d7e2, -bg => 0x162834, -attrs => 0),
            MUTED => TerminalStyle::new(-fg => 0x8fa5b3, -bg => 0x10202c, -attrs => 0),
            ACCENT => TerminalStyle::new(-fg => 0x8fd3ff, -bg => 0x10202c, -attrs => 0),
            SUCCESS => TerminalStyle::new(-fg => 0x9ce28f, -bg => 0x10202c, -attrs => 0),
            WARNING => TerminalStyle::new(-fg => 0xf4d38b, -bg => 0x10202c, -attrs => 0),
            DANGER => TerminalStyle::new(-fg => 0xff8f8f, -bg => 0x10202c, -attrs => 0),
            CORNER => TerminalStyle::new(-fg => 0xf0f6fa, -bg => 0x081018, -attrs => 0),
            CENTER => TerminalStyle::new(-fg => 0xf0f6fa, -bg => 0x10202c, -attrs => 0),
        );
        return $styles{$material} // $styles{DEFAULT};
    });

    my $border_mapper = BorderMapper::from_callback(sub ($material) {
        state %styles = (
            DEFAULT => TerminalBorderStyle::new(),
            FRAME => TerminalBorderStyle::new(
                -fg => 0x8eb2c2,
                -bg => 0x10202c,
                -attrs => 0,
                -border => ['┌', '─', '┐', '│', ' ', '│', '└', '─', '┘'],
            ),
            FRAME_ALT => TerminalBorderStyle::new(
                -fg => 0x8fd3ff,
                -bg => 0x162834,
                -attrs => 0,
                -border => ['┌', '─', '┐', '│', ' ', '│', '└', '─', '┘'],
            ),
            HEAVY => TerminalBorderStyle::new(
                -fg => 0xf4d38b,
                -bg => 0x10202c,
                -attrs => 0,
                -border => ['╔', '═', '╗', '║', ' ', '║', '╚', '═', '╝'],
            ),
        );
        return $styles{$material} // $styles{DEFAULT};
    });

    return Theme::new(
        -material_mapper => $material_mapper,
        -border_mapper => $border_mapper,
    );
}

1;

__END__

=pod

=head1 NAME

LayoutTheme - shared semantic theme for layout examples

=head1 SYNOPSIS

  use LayoutTheme;
  my $theme = LayoutTheme::build_theme();

=head1 DESCRIPTION

Provides a compact material and border theme for the example layout apps.

=cut
