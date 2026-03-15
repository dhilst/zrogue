use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use ZTUI::GameLoop;
use InputTheme;
use ZTUI::TML qw(App Layer InputRoot VBox BBox Rect TextViewport Text OnKey OnUpdate);

my @lines = (
    'A quiet message log unfolds below.',
    'Line 02: the player inspects the ruins.',
    'Line 03: distant metal echoes in the hall.',
    'Line 04: torchlight catches on wet stone.',
    'Line 05: a draft moves through a cracked arch.',
    'Line 06: something shuffles just out of view.',
);
my %state = (scroll => 0);
my $theme = InputTheme::build_theme();

my $ui = App {
    OnUpdate {
        my ($app, $dt, @events) = @_;
        my $state = $app->state;
        my $needs_render = !$state->{bootstrapped};
        $state->{bootstrapped} = 1;
        $needs_render = 1 if @events;
        $app->skip_render unless $needs_render;
    };

    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'TextViewport', -material => 'TITLE';
                Text {} -text => 'j/k scrolls by line, f/b pages.', -material => 'MUTED';
                InputRoot {
                    TextViewport {}
                        -lines_ref => \@lines,
                        -scroll_ref => \$state{scroll},
                        -width => 34,
                        -height => 4,
                        -focused_material => 'FOCUS',
                        -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Scroll: ' . $app->state->{scroll} }, -material => 'VALUE';
            } -gap => 1;
        } -width => 42, -height => 11, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -19, -y => 5;
} -state => \%state;

ZTUI::GameLoop::new($theme, $ui)->run();
