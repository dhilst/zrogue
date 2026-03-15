use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message progress_ratio format_exit_report);
use ZTUI::TML qw(App Layer InputRoot FocusScope VBox BBox Rect Text Button ButtonRow OnKey OnUpdate);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 09: ButtonRow Progress', -material => 'TITLE';
                Text {} -text => 'Use j/k to choose Fast or Slow.', -material => 'MUTED';
                InputRoot {
                    FocusScope {
                        ButtonRow {
                            Button {} -label => 'Fast', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->start_action('fast', 3) }, -margin => 0;
                            Button {} -label => 'Slow', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->start_action('slow', 5) }, -margin => 0;
                        } -margin => 0;
                    } -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) . ' ' . progress_ratio($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 42, -height => 10, -material => 'PANEL', -border_material => 'HEAVY';
    } -x => -19, -y => 4;
} -state => {},
  -action => sub ($app, $report, $mode, $count) {
      for my $step (1 .. $count) {
          $report->({ message => "$mode step", current => $step, total => $count });
          sleep_step($mode eq 'fast' ? 0.08 : 0.16);
      }
      return { mode => $mode, count => $count };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('09-buttonrow-progress', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

09-buttonrow-progress.pl

=head1 DESCRIPTION

Shows a simple two-branch action launcher with visible progress ratios.

=cut
