package InputTheme;
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
            DEFAULT => TerminalStyle::new(-fg => 0xdfe8ee, -bg => 0x0d1419, -attrs => 0),
            BACKDROP => TerminalStyle::new(-fg => -1, -bg => 0x0d1419, -attrs => 0),
            PANEL => TerminalStyle::new(-fg => 0xdfe8ee, -bg => 0x172128, -attrs => 0),
            PANEL_ALT => TerminalStyle::new(-fg => 0xdfe8ee, -bg => 0x21313b, -attrs => 0),
            TITLE => TerminalStyle::new(-fg => 0xf6f4e8, -bg => 0x172128, -attrs => 0),
            TEXT => TerminalStyle::new(-fg => 0xdfe8ee, -bg => 0x172128, -attrs => 0),
            MUTED => TerminalStyle::new(-fg => 0x93a7b3, -bg => 0x172128, -attrs => 0),
            FOCUS => TerminalStyle::new(-fg => 0x0d1419, -bg => 0xf0c674, -attrs => 1),
            VALUE => TerminalStyle::new(-fg => 0x8dd3c7, -bg => 0x172128, -attrs => 0),
            SUCCESS => TerminalStyle::new(-fg => 0x9fe870, -bg => 0x172128, -attrs => 0),
            WARNING => TerminalStyle::new(-fg => 0xf0c674, -bg => 0x172128, -attrs => 0),
            DANGER => TerminalStyle::new(-fg => 0xf2777a, -bg => 0x172128, -attrs => 0),
        );
        return $styles{$material} // $styles{DEFAULT};
    });

    my $border_mapper = BorderMapper::from_callback(sub ($material) {
        state %styles = (
            DEFAULT => TerminalBorderStyle::new(),
            FRAME => TerminalBorderStyle::new(
                -fg => 0x87a7b7,
                -bg => 0x172128,
                -attrs => 0,
                -border => ['┌', '─', '┐', '│', ' ', '│', '└', '─', '┘'],
            ),
            HEAVY => TerminalBorderStyle::new(
                -fg => 0xf0c674,
                -bg => 0x172128,
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
