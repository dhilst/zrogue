use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use ZTUI::GameLoop;
use LayoutTheme;
use ZTUI::TML qw(App Layer VBox HBox BBox Rect Text OnKey OnUpdate);

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

        VBox {
            BBox {
                HBox {
                    Text {} -text => 'Nested Layout Example', -material => 'TITLE';
                    Text {} -text => 'q quit', -material => 'WARNING';
                } -width => '100%',
                  -gap => 2,
                  -align => 'center';
            } -width => '100%',
              -height => '18%',
              -material => 'PANEL_ALT',
              -border_material => 'FRAME_ALT';

            HBox {
                BBox {
                    VBox {
                        Text {} -text => 'Filters', -material => 'TITLE';
                        BBox {
                            VBox {
                                Text {} -text => 'Region: Northern Reach', -material => 'TEXT';
                                Text {} -text => 'Level : 10-14', -material => 'TEXT';
                            } -gap => 0;
                        } -width => '100%',
                          -height => '36%',
                          -material => 'PANEL_SOFT',
                          -border_material => 'FRAME';

                        BBox {
                            VBox {
                                Text {} -text => 'Tags', -material => 'TEXT';
                                Text {} -text => 'Ruins, Forest, Camp', -material => 'MUTED';
                            } -gap => 0;
                        } -width => '100%',
                          -height => '30%',
                          -material => 'PANEL_SOFT',
                          -border_material => 'FRAME';
                    } -gap => 1;
                } -width => '28%',
                  -height => '100%',
                  -material => 'PANEL',
                  -border_material => 'FRAME';

                VBox {
                    BBox {
                        Text {} -text => 'Primary Content', -material => 'TITLE';
                    } -width => '100%',
                      -height => '20%',
                      -material => 'PANEL',
                      -border_material => 'HEAVY';

                    HBox {
                        BBox {
                            VBox {
                                Text {} -text => 'Summary', -material => 'ACCENT';
                                Text {} -text => 'A nested split view is useful for dashboards.', -material => 'TEXT';
                            } -gap => 1;
                        } -width => '52%',
                          -height => '100%',
                          -material => 'PANEL_ALT',
                          -border_material => 'FRAME_ALT';

                        BBox {
                            VBox {
                                Text {} -text => 'Details', -material => 'SUCCESS';
                                Text {} -text => 'Compose VBox/HBox/BBox layers to build richer shells.', -material => 'TEXT_ALT';
                            } -gap => 1;
                        } -width => '48%',
                          -height => '100%',
                          -material => 'PANEL',
                          -border_material => 'FRAME';
                    } -width => '100%',
                      -height => '42%',
                      -gap => 1;

                    BBox {
                        VBox {
                            Text {} -text => 'Footer Block', -material => 'TITLE';
                            Text {} -text => 'Common use case: header + split body + footer.', -material => 'TEXT';
                        } -gap => 1;
                    } -width => '100%',
                      -height => '38%',
                      -material => 'PANEL_ALT',
                      -border_material => 'FRAME_ALT';
                } -width => '72%',
                  -height => '100%',
                  -gap => 1;
            } -width => '100%',
              -height => '82%',
              -gap => 1;
        } -x => 0,
          -y => 0,
          -width => '86%',
          -height => '74%',
          -gap => 1;
    } -x => sub ($app, $renderer, $node) {
            return -int($renderer->width / 2) + int($renderer->width * 0.07);
        },
      -y => sub ($app, $renderer, $node) {
            return int($renderer->height / 2) - int($renderer->height * 0.12);
        };
} -state => {};

ZTUI::GameLoop::new($theme, $ui)->run();

__END__

=pod

=head1 NAME

05-nested-layouts.pl - nested layout composition example

=head1 SYNOPSIS

  perl examples/layout/05-nested-layouts.pl

=head1 DESCRIPTION

Shows a more realistic nested shell with a header, sidebar, split content, and footer.

=cut
