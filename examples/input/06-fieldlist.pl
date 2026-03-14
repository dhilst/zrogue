use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use GameLoop;
use InputTheme;
use TML qw(App Layer InputRoot FocusScope VBox BBox Rect FieldList Text OnKey OnUpdate);

my %state = (
    name => 'Ada',
    code => 'ZX-81',
    debug => 1,
);
my @fields = (
    { label => 'Name', type => 'text', value_ref => \$state{name}, width => 10 },
    { label => 'Code', type => 'text', value_ref => \$state{code}, width => 10 },
    { label => 'Debug', type => 'toggle', value_ref => \$state{debug} },
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
                Text {} -text => 'FieldList', -material => 'TITLE';
                Text {} -text => 'FieldList is now interactive. j/k moves fields, Enter edits text or toggles booleans.', -material => 'MUTED';
                InputRoot {
                    FocusScope {
                        FieldList {}
                            -fields => \@fields,
                            -material => 'TEXT',
                            -focused_material => 'FOCUS',
                            -active_material => 'FOCUS',
                            -margin => 0;
                    } -margin => 0;
                } -margin => 0;
                Text {} -text => 'Enter saves text edits, Esc cancels text edits, Space also toggles boolean fields, q quits.', -material => 'WARNING';
            } -gap => 1;
        } -width => 50, -height => 14, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -23, -y => 6;
} -state => \%state;

GameLoop::new($theme, $ui)->run();
