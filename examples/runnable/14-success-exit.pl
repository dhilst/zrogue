use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use ZTUI::TML qw(App Layer InputRoot VBox BBox Rect Text Button OnKey OnUpdate);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 14: Success Exit', -material => 'TITLE';
                Text {} -text => 'Press Run to finish with exit code 0.', -material => 'MUTED';
                InputRoot {
                    Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->start_action('success') }, -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 44, -height => 10, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -20, -y => 4;
} -state => {},
  -action => sub ($app, $report, $mode) {
      $report->({ message => "mode $mode" });
      sleep_step(0.10);
      return { mode => $mode, ok => 1 };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('14-success-exit', $result);
      exit 0;
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

14-success-exit.pl

=head1 DESCRIPTION

Small example showing a successful action followed by an explicit exit code 0
from the `-exit` callback.

=cut
