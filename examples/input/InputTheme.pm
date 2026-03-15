package InputTheme;
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
            DEFAULT => ZTUI::TerminalStyle::new(-fg => 0xdfe8ee, -bg => 0x0d1419, -attrs => 0),
            BACKDROP => ZTUI::TerminalStyle::new(-fg => -1, -bg => 0x0d1419, -attrs => 0),
            PANEL => ZTUI::TerminalStyle::new(-fg => 0xdfe8ee, -bg => 0x172128, -attrs => 0),
            PANEL_ALT => ZTUI::TerminalStyle::new(-fg => 0xdfe8ee, -bg => 0x21313b, -attrs => 0),
            TITLE => ZTUI::TerminalStyle::new(-fg => 0xf6f4e8, -bg => 0x172128, -attrs => 0),
            TEXT => ZTUI::TerminalStyle::new(-fg => 0xdfe8ee, -bg => 0x172128, -attrs => 0),
            MUTED => ZTUI::TerminalStyle::new(-fg => 0x93a7b3, -bg => 0x172128, -attrs => 0),
            FOCUS => ZTUI::TerminalStyle::new(-fg => 0x0d1419, -bg => 0xf0c674, -attrs => 1),
            VALUE => ZTUI::TerminalStyle::new(-fg => 0x8dd3c7, -bg => 0x172128, -attrs => 0),
            SUCCESS => ZTUI::TerminalStyle::new(-fg => 0x9fe870, -bg => 0x172128, -attrs => 0),
            WARNING => ZTUI::TerminalStyle::new(-fg => 0xf0c674, -bg => 0x172128, -attrs => 0),
            DANGER => ZTUI::TerminalStyle::new(-fg => 0xf2777a, -bg => 0x172128, -attrs => 0),
        );
        return $styles{$material} // $styles{DEFAULT};
    });

    my $border_mapper = ZTUI::BorderMapper::from_callback(sub ($material) {
        state %styles = (
            DEFAULT => ZTUI::TerminalBorderStyle::new(),
            FRAME => ZTUI::TerminalBorderStyle::new(
                -fg => 0x87a7b7,
                -bg => 0x172128,
                -attrs => 0,
                -border => ['┌', '─', '┐', '│', ' ', '│', '└', '─', '┘'],
            ),
            HEAVY => ZTUI::TerminalBorderStyle::new(
                -fg => 0xf0c674,
                -bg => 0x172128,
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
