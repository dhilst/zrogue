use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use GameLoop;
use LayoutTheme;
use TML qw(App Layer Rect Text OnKey OnUpdate);

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

        Text {}
            -x => 1,
            -y => -1,
            -text => 'TOP LEFT',
            -material => 'CORNER';

        Text {}
            -x => sub ($app, $renderer, $node) {
                return $renderer->width - 11;
            },
            -y => -1,
            -text => 'TOP RIGHT',
            -material => 'CORNER';

        Text {}
            -x => 1,
            -y => sub ($app, $renderer, $node) {
                return -($renderer->height - 2);
            },
            -text => 'BOTTOM LEFT',
            -material => 'CORNER';

        Text {}
            -x => sub ($app, $renderer, $node) {
                return $renderer->width - 14;
            },
            -y => sub ($app, $renderer, $node) {
                return -($renderer->height - 2);
            },
            -text => 'BOTTOM RIGHT',
            -material => 'CORNER';
    } -x => sub ($app, $renderer, $node) {
            return -int($renderer->width / 2) + 1;
        },
      -y => sub ($app, $renderer, $node) {
            return int($renderer->height / 2) - 1;
        };
} -state => {};

GameLoop::new($theme, $ui)->run();

__END__

=pod

=head1 NAME

04-corner-text.pl - corner anchored text example

=head1 SYNOPSIS

  perl examples/layout/04-corner-text.pl

=head1 DESCRIPTION

Shows direct corner anchoring for HUD labels and overlay text.

=cut
