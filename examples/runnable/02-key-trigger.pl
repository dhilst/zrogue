use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use TML qw(App Layer VBox BBox Rect Text OnKey OnUpdate);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'a' => sub ($app, $event) { $app->start_action('hotkey') unless $app->action_is_running };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 02: Key Trigger', -material => 'TITLE';
                Text {} -text => 'Press a to start the action. Press q to quit idle.', -material => 'MUTED';
                Text {} -text => sub ($app, $renderer, $node) { 'Phase: ' . $app->action_phase }, -material => 'VALUE';
                Text {} -text => sub ($app, $renderer, $node) { 'Message: ' . progress_message($app) }, -material => 'TEXT';
            } -gap => 1;
        } -width => 48, -height => 9, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -22, -y => 4;
} -state => {},
  -action => sub ($app, $report, $label) {
      $report->({ message => 'accepted hotkey' });
      sleep_step(0.20);
      $report->({ message => 'finishing hotkey' });
      sleep_step(0.20);
      return { trigger => $label, status => 'ok' };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('02-key-trigger', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

02-key-trigger.pl

=head1 DESCRIPTION

Demonstrates an app-level key binding that starts the lifecycle action without
using the input widget tree.

=cut
