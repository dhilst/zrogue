use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin/input";

use InputTheme;
use ZTUI::TML qw(App Layer VBox BBox Rect Text OnKey OnUpdate);

my $state = {
    frames   => 0,
    elapsed  => 0.0,
    fps      => 0.0,
    status   => 'Press q to quit',
    ticked   => 0,
};

my $ui = App {
    OnUpdate {
        my ($app, $dt, @events) = @_;
        my $state = $app->state;

        $state->{frames}++;
        $state->{ticked} += $dt;
        $state->{elapsed} += $dt;

        if ($state->{elapsed} >= 1.0) {
            $state->{fps} = $state->{frames} / $state->{elapsed};
            $state->{frames} = 0;
            $state->{elapsed} = 0.0;
            $state->{status} = sprintf('FPS %.1f', $state->{fps});
        }

        $app->skip_render unless @events;
    };

    OnKey 'q' => sub ($app, $event) {
        $app->quit;
    };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'ztui demo', -material => 'TITLE';
                Text {} -text => sub ($app, $renderer, $node) {
                    return $app->state->{status};
                }, -material => 'TEXT';
                Text {} -text => sub ($app, $renderer, $node) {
                    return 'Runtime: ' . sprintf('%.3f', $app->state->{ticked});
                }, -material => 'TEXT';
                Text {} -text => 'Press q to quit', -material => 'MUTED';
            } -gap => 1;
        } -width => 46, -height => 10, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -23, -y => 5;
} -state => $state;

$ui->run(InputTheme::build_theme());

__END__

=pod

=head1 NAME

zrogue.pl - small ZTUI runnable demo

=head1 DESCRIPTION

Simple demo that renders a demo panel with live frame-rate status and exits on
q.

=cut
