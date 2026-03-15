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
                Text {} -text => 'Centered Message', -material => 'TITLE';
                Text {} -text => 'Use this for splash screens, prompts, and dialog-like views.', -material => 'TEXT';
                Text {} -text => 'Press q to close', -material => 'ACCENT';
            } -width => '100%',
              -gap => 1,
              -align => 'center';
        } -x => sub ($app, $renderer, $node) {
                return -int($renderer->width * 0.18);
            },
          -y => sub ($app, $renderer, $node) {
                return int($renderer->height * 0.18);
            },
          -width => '36%',
          -height => '24%',
          -material => 'CENTER',
          -border_material => 'HEAVY';
    };
} -state => {};

ZTUI::GameLoop::new($theme, $ui)->run();

__END__

=pod

=head1 NAME

03-centered-text.pl - centered text layout example

=head1 SYNOPSIS

  perl examples/layout/03-centered-text.pl

=head1 DESCRIPTION

Shows a compact centered panel with centered text content.

=cut
