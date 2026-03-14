use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use TML qw(App Layer InputRoot VBox BBox Rect Text Button ButtonRow OnKey OnUpdate);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 12: Custom Keymap', -material => 'TITLE';
                Text {} -text => 'Use l/h for local movement because InputRoot overrides the keymap.', -material => 'MUTED';
                InputRoot {
                    ButtonRow {
                        Button {} -label => 'Alpha', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->start_action('alpha') }, -margin => 0;
                        Button {} -label => 'Bravo', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->start_action('bravo') }, -margin => 0;
                    } -margin => 0;
                } -margin => 0,
                  -keymap => {
                      next => ['l'],
                      prev => ['h'],
                      exit_next => ['L'],
                      exit_prev => ['H'],
                  };
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 60, -height => 10, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -28, -y => 4;
} -state => {},
  -action => sub ($app, $report, $label) {
      $report->({ message => "selected $label" });
      sleep_step(0.15);
      return { label => $label };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('12-custom-keymap', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

12-custom-keymap.pl

=head1 DESCRIPTION

Shows root-level keymap overrides while still using the runnable lifecycle.

=cut
