use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use GameLoop;
use InputTheme;
use TML qw(App Layer InputRoot VBox BBox Rect List Text OnKey OnUpdate);

my @items = map { +{ label => $_ } } qw(Alpha Bravo Charlie Delta Echo Foxtrot);
my %state = (selected => 0, last => 'none');
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
                Text {} -text => 'List', -material => 'TITLE';
                Text {} -text => 'j/k moves, Space or Enter activates.', -material => 'MUTED';
                InputRoot {
                    List {}
                        -items_ref => \@items,
                        -selected_index_ref => \$state{selected},
                        -height => 4,
                        -width => 14,
                        -focused_material => 'FOCUS',
                        -on_activate => sub ($app, $node, $idx, $item) {
                            $app->state->{last} = $item->{label};
                        },
                        -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Selected: ' . $items[$app->state->{selected}]{label} }, -material => 'VALUE';
                Text {} -text => sub ($app, $renderer, $node) { 'Last activation: ' . $app->state->{last} }, -material => 'VALUE';
            } -gap => 1;
        } -width => 28, -height => 11, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -12, -y => 5;
} -state => \%state;

GameLoop::new($theme, $ui)->run();
