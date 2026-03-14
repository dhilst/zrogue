use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use GameLoop;
use InputTheme;
use TML qw(App Layer InputRoot FocusScope VBox BBox Rect Text Button ButtonRow OnKey OnUpdate);

my %state = (result => 'pending');
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
                Text {} -text => 'yesno dialog', -material => 'TITLE';
                Text {} -text => 'Replace the current save slot?', -material => 'TEXT';
                Text {} -text => 'Use j/k to switch buttons. Space or Enter activates.', -material => 'MUTED';
                InputRoot {
                    FocusScope {
                        ButtonRow {
                            Button {} -label => 'Yes', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->state->{result} = 'yes' }, -margin => 0;
                            Button {} -label => 'No', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->state->{result} = 'no' }, -margin => 0;
                        } -align => 'center', -margin => 0;
                    } -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Result: ' . $app->state->{result} }, -material => 'VALUE';
            } -gap => 1, -align => 'center';
        } -width => 34, -height => 9, -material => 'PANEL', -border_material => 'HEAVY';
    } -x => -15, -y => 4;
} -state => \%state;

GameLoop::new($theme, $ui)->run();
