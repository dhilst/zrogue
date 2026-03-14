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
                Text {} -text => 'Runnable 16: STDERR Capture', -material => 'TITLE';
                Text {} -text => 'The action writes diagnostics to STDERR, not to the TUI terminal.', -material => 'MUTED';
                InputRoot {
                    Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->start_action('stderr') }, -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 62, -height => 10, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -29, -y => 4;
} -state => {},
  -action => sub ($app, $report, $label) {
      $report->({ message => "emit $label" });
      warn "diagnostic:$label\n";
      sleep_step(0.12);
      return { label => $label };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('16-stderr-report', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

16-stderr-report.pl

=head1 DESCRIPTION

Captures STDERR emitted by the action worker and prints it after the terminal is
returned to text mode.

=cut
