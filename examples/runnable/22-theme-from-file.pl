use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use TML qw(App Layer HBox VBox BBox Rect Text Button OnKey OnUpdate InputRoot);
use Theme;

my %state = (
    sample_items => [ 'Load theme', 'Inspect renderer output', 'Press q to quit' ],
    status => 'ini theme loaded from file',
);

my $theme = Theme::from_file("$Bin/22-theme-from-file.ini");

my $ui = App {
    OnUpdate { frame_update(@_) };

    OnKey 'q' => sub ($app, $event) {
        $app->quit;
    };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 22: Theme from INI', -material => 'TITLE';
                Text {} -text => 'This demo proves Theme::from_file.', -material => 'TEXT';

                Text {} -text => sub ($app, $renderer, $node) {
                    return 'status: ' . ($app->state->{status} // 'ok');
                }, -material => 'VALUE';

                InputRoot {
                    Button {}
                        -label => 'Run',
                        -focused_material => 'FOCUS',
                        -on_press => sub ($app, $node) {
                            $app->state->{status} = 'button pressed';
                        },
                        -margin => 0;
                } -margin => 0;
            } -gap => 1;
        } -width => 58, -height => 11, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -29, -y => 5;
} -state => \%state;

$ui->run($theme);

sub frame_update($app, $dt, @events) {
    $app->skip_render unless @events;
    return;
}

__END__

=head1 NAME

22-theme-from-file.pl

=head1 DESCRIPTION

Demonstrates loading a theme from an INI file using C<Theme::from_file>. Run from
repo root with:

  perl examples/runnable/22-theme-from-file.pl

=cut
