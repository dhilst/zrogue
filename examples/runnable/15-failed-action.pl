use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use TML qw(App Layer InputRoot VBox BBox Rect Text Button OnKey OnUpdate);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 15: Failed Exit', -material => 'TITLE';
                Text {} -text => 'Press Run to return a failure payload. Exit will return status 3.', -material => 'MUTED';
                InputRoot {
                    Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->start_action('fail') }, -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 48, -height => 10, -material => 'PANEL', -border_material => 'HEAVY';
    } -x => -22, -y => 4;
} -state => {},
  -action => sub ($app, $report, $mode) {
      $report->({ message => "mark failed $mode" });
      sleep_step(0.15);
      return { mode => $mode, status => 'failed' };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('15-failed-action', $result);
      exit 3;
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

15-failed-action.pl

=head1 DESCRIPTION

The action returns a failure payload, and the `-exit` callback maps that result
to process exit status 3 after restoring the terminal.

=cut
