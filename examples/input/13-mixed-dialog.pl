use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use GameLoop;
use InputTheme;
use TML qw(App Layer InputRoot FocusScope VBox HBox BBox Rect Text TextField Toggle Button ButtonRow List TextViewport OnKey OnUpdate);

my @targets = map { +{ label => $_ } } ('Ruins Gate', 'Archive Lift', 'Signal Tower', 'Flooded Vault');
my @log_lines = (
    'Mission briefing:',
    '1. Pick an insertion route.',
    '2. Set optional flags.',
    '3. Confirm the launch sequence.',
    '4. Review the destination notes.',
    '5. Exit with q when done.',
);
my %state = (
    codename => 'ASH',
    safe_mode => 1,
    target_idx => 0,
    log_scroll => 0,
    result => 'standby',
);
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
                Text {} -text => 'mixed dialog', -material => 'TITLE';
                Text {} -text => 'Use j/k inside the active container. Use J/K to jump between the left and right panes.', -material => 'MUTED';
                InputRoot {
                    FocusScope {
                        HBox {
                            VBox {
                                Text {} -text => 'Codename', -material => 'TEXT';
                                TextField {} -value_ref => \$state{codename}, -width => 10, -focused_material => 'FOCUS', -active_material => 'FOCUS', -margin => 0;
                                Toggle {} -label => 'Safe mode', -value_ref => \$state{safe_mode}, -focused_material => 'FOCUS', -margin => 0;
                                List {}
                                    -items_ref => \@targets,
                                    -selected_index_ref => \$state{target_idx},
                                    -height => 4,
                                    -width => 16,
                                    -focused_material => 'FOCUS',
                                    -margin => 0;
                            } -gap => 1, -width => 18, -margin => 0;
                            VBox {
                                Text {} -text => 'Notes', -material => 'TEXT';
                                TextViewport {}
                                    -lines_ref => \@log_lines,
                                    -scroll_ref => \$state{log_scroll},
                                    -width => 24,
                                    -height => 6,
                                    -focused_material => 'FOCUS',
                                    -margin => 0;
                                ButtonRow {
                                    Button {} -label => 'Launch', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                                        my $target = $targets[$app->state->{target_idx}]{label};
                                        $app->state->{result} = 'launch ' . $target;
                                    }, -margin => 0;
                                    Button {} -label => 'Abort', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->state->{result} = 'abort' }, -margin => 0;
                                } -margin => 0;
                            } -gap => 1, -width => 26, -margin => 0;
                        } -gap => 2, -margin => 0;
                    } -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) {
                    my $target = $targets[$app->state->{target_idx}]{label};
                    return 'Result: ' . $app->state->{result} . ' | Target: ' . $target;
                }, -material => 'VALUE';
            } -gap => 1;
        } -width => 54, -height => 18, -material => 'PANEL_ALT', -border_material => 'HEAVY';
    } -x => -25, -y => 8;
} -state => \%state;

GameLoop::new($theme, $ui)->run();
