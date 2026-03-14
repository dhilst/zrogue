use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use GameLoop;
use InputTheme;
use TML qw(App Layer InputRoot VBox BBox Rect Button Text OnKey OnUpdate);

my %state = (presses => 0);
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
                Text {} -text => 'Button', -material => 'TITLE';
                Text {} -text => 'Press Space or Enter. q quits.', -material => 'MUTED';
                InputRoot {
                    Button {}
                        -label => 'Trigger',
                        -focused_material => 'FOCUS',
                        -on_press => sub ($app, $node) { $app->state->{presses}++ },
                        -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Press count: ' . $app->state->{presses} }, -material => 'VALUE';
            } -gap => 1;
        } -width => 28, -height => 8, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -12, -y => 3;
} -state => \%state;

GameLoop::new($theme, $ui)->run();
