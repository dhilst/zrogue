use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use GameLoop;
use InputTheme;
use TML qw(App Layer InputRoot VBox BBox Rect TextField Text OnKey OnUpdate);

my %state = (name => '');
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
                Text {} -text => 'TextField', -material => 'TITLE';
                Text {} -text => 'Enter edits, Enter saves, Esc cancels, q quits.', -material => 'MUTED';
                InputRoot {
                    TextField {}
                        -value_ref => \$state{name},
                        -width => 18,
                        -focused_material => 'FOCUS',
                        -active_material => 'FOCUS',
                        -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Value: ' . ($app->state->{name} eq '' ? '<empty>' : $app->state->{name}) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 34, -height => 8, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -15, -y => 3;
} -state => \%state;

GameLoop::new($theme, $ui)->run();
