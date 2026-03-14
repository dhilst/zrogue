use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use GameLoop;
use LayoutTheme;
use TML qw(App Layer VBox HBox BBox Rect Text OnKey OnUpdate);

my $theme = LayoutTheme::build_theme();

my $ui = App {
    OnUpdate {
        my ($app, $dt, @events) = @_;
        my $state = $app->state;
        my $needs_render = !$state->{bootstrapped};
        $state->{bootstrapped} = 1;
        $needs_render = 1 if @events;
        $app->skip_render unless $needs_render;
    };

    OnKey 'q' => sub ($app, $event) {
        $app->quit;
    };

    Layer {
        Rect {}
            -x => 0,
            -y => 0,
            -width => '100%',
            -height => '100%',
            -material => 'BACKDROP';

        HBox {
            BBox {
                VBox {
                    Text {} -text => 'Party', -material => 'TITLE';
                    Text {} -text => 'Aela the Ranger', -material => 'TEXT';
                    Text {} -text => 'Doran the Smith', -material => 'TEXT';
                    Text {} -text => 'Mira the Scholar', -material => 'TEXT';
                } -gap => 1;
            } -width => '30%',
              -height => '100%',
              -material => 'PANEL',
              -border_material => 'FRAME';

            BBox {
                VBox {
                    Text {} -text => 'World Map', -material => 'TITLE';
                    Text {} -text => 'Forest of Cinders', -material => 'TEXT_ALT';
                    Text {} -text => 'Old Causeway', -material => 'TEXT_ALT';
                    Text {} -text => 'Watchtower Basin', -material => 'TEXT_ALT';
                    Text {} -text => 'This middle column usually carries the main content.', -material => 'MUTED';
                } -gap => 1;
            } -width => '40%',
              -height => '100%',
              -material => 'PANEL_ALT',
              -border_material => 'FRAME_ALT';

            BBox {
                VBox {
                    Text {} -text => 'Actions', -material => 'TITLE';
                    Text {} -text => '[E] Inspect', -material => 'ACCENT';
                    Text {} -text => '[R] Rest', -material => 'SUCCESS';
                    Text {} -text => '[F] Use torch', -material => 'WARNING';
                    Text {} -text => '[Q] Quit', -material => 'DANGER';
                } -gap => 1;
            } -width => '30%',
              -height => '100%',
              -material => 'PANEL',
              -border_material => 'FRAME';
        } -x => 0,
          -y => 0,
          -width => '84%',
          -height => '68%',
          -gap => 1;
    } -x => sub ($app, $renderer, $node) {
            return -int($renderer->width / 2) + int($renderer->width * 0.08);
        },
      -y => sub ($app, $renderer, $node) {
            return int($renderer->height / 2) - int($renderer->height * 0.16);
        };
} -state => {};

GameLoop::new($theme, $ui)->run();

__END__

=pod

=head1 NAME

02-multiple-columns.pl - multi-column layout example

=head1 SYNOPSIS

  perl examples/layout/02-multiple-columns.pl

=head1 DESCRIPTION

Shows a common three-column application layout with navigation, content, and actions.

=cut
