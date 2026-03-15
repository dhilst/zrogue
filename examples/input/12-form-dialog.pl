use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use ZTUI::GameLoop;
use InputTheme;
use ZTUI::TML qw(App Layer InputRoot FocusScope VBox BBox Rect Text Button ButtonRow FieldList OnKey OnUpdate);

my %state = (
    name => 'Ada',
    guild => 'North',
    hardcore => 0,
    saved => 'pending',
);
my @fields = (
    { label => 'Name', type => 'text', value_ref => \$state{name}, width => 12 },
    { label => 'Guild', type => 'text', value_ref => \$state{guild}, width => 12 },
    { label => 'Hardcore', type => 'toggle', value_ref => \$state{hardcore} },
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
                Text {} -text => 'form dialog', -material => 'TITLE';
                Text {} -text => 'j/k moves fields. J jumps to the buttons. Enter edits or toggles, Esc cancels.', -material => 'MUTED';
                InputRoot {
                    FocusScope {
                        VBox {
                            FieldList {}
                                -fields => \@fields,
                                -material => 'TEXT',
                                -focused_material => 'FOCUS',
                                -active_material => 'FOCUS',
                                -margin => 0;
                            ButtonRow {
                                Button {} -label => 'Save', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->state->{saved} = 'saved' }, -margin => 0;
                                Button {} -label => 'Cancel', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->state->{saved} = 'cancelled' }, -margin => 0;
                            } -margin => 0;
                        } -gap => 1;
                    } -margin => 0;
                } -margin => 0;
                FieldList {} -fields => \@fields, -material => 'MUTED', -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Status: ' . $app->state->{saved} }, -material => 'VALUE';
            } -gap => 1;
        } -width => 42, -height => 18, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -19, -y => 8;
} -state => \%state;

ZTUI::GameLoop::new($theme, $ui)->run();
