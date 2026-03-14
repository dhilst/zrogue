use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use GameLoop;
use InputTheme;
use TML qw(App Layer InputRoot VBox BBox Rect Toggle Text OnKey OnUpdate);

my %state = (enabled => 0);
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
                Text {} -text => 'Toggle', -material => 'TITLE';
                Text {} -text => 'Use Space or Enter to flip the value.', -material => 'MUTED';
                InputRoot {
                    Toggle {}
                        -label => 'Enable debug traces',
                        -value_ref => \$state{enabled},
                        -focused_material => 'FOCUS',
                        -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) {
                    return $app->state->{enabled} ? 'State: enabled' : 'State: disabled';
                }, -material => 'VALUE';
            } -gap => 1;
        } -width => 40, -height => 8, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -18, -y => 3;
} -state => \%state;

GameLoop::new($theme, $ui)->run();
