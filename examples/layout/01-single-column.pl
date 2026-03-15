use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use ZTUI::GameLoop;
use LayoutTheme;
use ZTUI::TML qw(App Layer VBox BBox Rect Text OnKey OnUpdate);

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

        BBox {
            VBox {
                Text {} -text => 'Single Column Layout', -material => 'TITLE';
                Text {} -text => 'A simple vertical stack for menus or forms.', -material => 'TEXT';
                Text {} -text => 'Inventory', -material => 'ACCENT';
                Text {} -text => 'Quest Log', -material => 'TEXT';
                Text {} -text => 'Party Status', -material => 'TEXT';
                Text {} -text => 'Settings', -material => 'TEXT';
                Text {} -text => 'Press q to quit', -material => 'WARNING';
            } -gap => 1;
        } -x => 0,
          -y => 0,
          -width => '42%',
          -height => '74%',
          -material => 'PANEL',
          -border_material => 'FRAME';
    } -x => sub ($app, $renderer, $node) {
            return -int($renderer->width / 2) + int($renderer->width * 0.08);
        },
      -y => sub ($app, $renderer, $node) {
            return int($renderer->height / 2) - int($renderer->height * 0.12);
        };
} -state => {};

ZTUI::GameLoop::new($theme, $ui)->run();

__END__

=pod

=head1 NAME

01-single-column.pl - single-column layout example

=head1 SYNOPSIS

  perl examples/layout/01-single-column.pl

=head1 DESCRIPTION

Shows a common vertical panel layout suitable for menus or sidebars.

=cut
