use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message progress_ratio format_exit_report);
use ZTUI::TML qw(App Layer InputRoot VBox BBox Rect Text Button OnKey OnUpdate);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 18: Multi-step Progress', -material => 'TITLE';
                Text {} -text => 'Watch a five-step action update the UI while it runs.', -material => 'MUTED';
                InputRoot {
                    Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->start_action('five-steps') }, -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Message: ' . progress_message($app) }, -material => 'VALUE';
                Text {} -text => sub ($app, $renderer, $node) { 'Ratio: ' . progress_ratio($app) }, -material => 'TEXT';
            } -gap => 1;
        } -width => 56, -height => 11, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -26, -y => 5;
} -state => {},
  -action => sub ($app, $report, $label) {
      for my $step (1 .. 5) {
          $report->({ message => "$label step $step", current => $step, total => 5 });
          sleep_step(0.10);
      }
      return { label => $label, steps => 5 };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('18-multi-step-progress', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

18-multi-step-progress.pl

=head1 DESCRIPTION

Emphasizes repeated progress reports from the action worker and a simple
progress-ratio display in the UI.

=cut
