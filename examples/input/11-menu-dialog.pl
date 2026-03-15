use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use ZTUI::GameLoop;
use InputTheme;
use ZTUI::TML qw(App Layer InputRoot FocusScope VBox BBox Rect Text Button ButtonRow List OnKey OnUpdate);

my @items = map { +{ label => $_ } } ('New Game', 'Continue', 'Options', 'Credits');
my %state = (selected => 0, result => 'none');
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
                Text {} -text => 'menu dialog', -material => 'TITLE';
                Text {} -text => 'Choose an action. j/k moves inside the menu, J jumps to the button row.', -material => 'MUTED';
                InputRoot {
                    FocusScope {
                        VBox {
                            List {}
                                -items_ref => \@items,
                                -selected_index_ref => \$state{selected},
                                -height => 4,
                                -width => 14,
                                -focused_material => 'FOCUS',
                                -on_activate => sub ($app, $node, $idx, $item) { $app->state->{result} = $item->{label} },
                                -margin => 0;
                            ButtonRow {
                                Button {} -label => 'OK', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->state->{result} = $items[$app->state->{selected}]{label} }, -margin => 0;
                                Button {} -label => 'Cancel', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->state->{result} = 'cancel' }, -margin => 0;
                            } -margin => 0;
                        } -gap => 1, -align => 'center';
                    } -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Result: ' . $app->state->{result} }, -material => 'VALUE';
            } -gap => 1, -align => 'center';
        } -width => 40, -height => 13, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -18, -y => 6;
} -state => \%state;

ZTUI::GameLoop::new($theme, $ui)->run();
