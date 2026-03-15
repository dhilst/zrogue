use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use GameLoop;
use InputTheme;
use TML qw(App Layer InputRoot VBox BBox Rect Text TextField OnKey OnUpdate);

my %state = (
    name => 'Ada',
    name_error => undef,
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
                Text {} -text => 'TextField Validation', -material => 'TITLE';
                Text {} -text => 'Enter edits, Enter saves, Esc cancels, q quits.', -material => 'MUTED';
                InputRoot {
                    VBox {
                        TextField {}
                            -value_ref => \$state{name},
                            -validate => qr/^[A-Za-z]{3,12}$/,
                            -on_change => sub ($app, $node, $new_value) {
                                delete $app->state->{name_error};
                            },
                            -on_submit => sub ($app, $node, $new_value) {
                                delete $app->state->{name_error};
                            },
                            -on_invalid => sub ($app, $node, $candidate) {
                                $app->state->{name_error} = "name must be 3-12 letters";
                            },
                            -width => 18,
                            -focused_material => 'FOCUS',
                            -active_material => 'FOCUS',
                            -margin => 0;
                        Text {} -text => sub ($app, $renderer, $node) { "Stored: $app->state->{name}" }, -material => 'VALUE';
                        Text {} -text => sub ($app, $renderer, $node) {
                            return 'Name: ' . $app->state->{name_error} if defined $app->state->{name_error};
                            return 'Name: ready';
                        },
                        -material => sub ($app, $renderer, $node) {
                            return defined $app->state->{name_error} ? 'DANGER' : 'MUTED';
                        },
                        -margin => 0;
                    } -gap => 1;
                } -margin => 0;
            } -gap => 1;
        } -width => 34, -height => 10, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -15, -y => 3;
} -state => \%state;

GameLoop::new($theme, $ui)->run();
