package LayoutTheme;
use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";

use ZTUI::BorderMapper;
use ZTUI::MaterialMapper;
use ZTUI::TerminalBorderStyle;
use ZTUI::TerminalStyle;
use ZTUI::Theme;

sub build_theme() {
    my $material_mapper = ZTUI::MaterialMapper::from_callback(sub ($material) {
        state %styles = (
            DEFAULT => ZTUI::TerminalStyle::new(-fg => 0xd7e3ea, -bg => 0x081018, -attrs => 0),
            BACKDROP => ZTUI::TerminalStyle::new(-fg => -1, -bg => 0x081018, -attrs => 0),
            PANEL => ZTUI::TerminalStyle::new(-fg => 0xd7e3ea, -bg => 0x10202c, -attrs => 0),
            PANEL_ALT => ZTUI::TerminalStyle::new(-fg => 0xd7e3ea, -bg => 0x162834, -attrs => 0),
            PANEL_SOFT => ZTUI::TerminalStyle::new(-fg => 0xd7e3ea, -bg => 0x122430, -attrs => 0),
            TITLE => ZTUI::TerminalStyle::new(-fg => 0xf0f6fa, -bg => 0x10202c, -attrs => 0),
            TEXT => ZTUI::TerminalStyle::new(-fg => 0xd7e3ea, -bg => 0x10202c, -attrs => 0),
            TEXT_ALT => ZTUI::TerminalStyle::new(-fg => 0xc5d7e2, -bg => 0x162834, -attrs => 0),
            MUTED => ZTUI::TerminalStyle::new(-fg => 0x8fa5b3, -bg => 0x10202c, -attrs => 0),
            ACCENT => ZTUI::TerminalStyle::new(-fg => 0x8fd3ff, -bg => 0x10202c, -attrs => 0),
            SUCCESS => ZTUI::TerminalStyle::new(-fg => 0x9ce28f, -bg => 0x10202c, -attrs => 0),
            WARNING => ZTUI::TerminalStyle::new(-fg => 0xf4d38b, -bg => 0x10202c, -attrs => 0),
            DANGER => ZTUI::TerminalStyle::new(-fg => 0xff8f8f, -bg => 0x10202c, -attrs => 0),
            CORNER => ZTUI::TerminalStyle::new(-fg => 0xf0f6fa, -bg => 0x081018, -attrs => 0),
            CENTER => ZTUI::TerminalStyle::new(-fg => 0xf0f6fa, -bg => 0x10202c, -attrs => 0),
        );
        return $styles{$material} // $styles{DEFAULT};
    });

    my $border_mapper = ZTUI::BorderMapper::from_callback(sub ($material) {
        state %styles = (
            DEFAULT => ZTUI::TerminalBorderStyle::new(),
            FRAME => ZTUI::TerminalBorderStyle::new(
                -fg => 0x8eb2c2,
                -bg => 0x10202c,
                -attrs => 0,
                -border => ['┌', '─', '┐', '│', ' ', '│', '└', '─', '┘'],
            ),
            FRAME_ALT => ZTUI::TerminalBorderStyle::new(
                -fg => 0x8fd3ff,
                -bg => 0x162834,
                -attrs => 0,
                -border => ['┌', '─', '┐', '│', ' ', '│', '└', '─', '┘'],
            ),
            HEAVY => ZTUI::TerminalBorderStyle::new(
                -fg => 0xf4d38b,
                -bg => 0x10202c,
                -attrs => 0,
                -border => ['╔', '═', '╗', '║', ' ', '║', '╚', '═', '╝'],
            ),
        );
        return $styles{$material} // $styles{DEFAULT};
    });

    return ZTUI::Theme::new(
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
