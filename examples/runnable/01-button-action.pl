use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message progress_ratio format_exit_report);
use ZTUI::TML qw(App Layer InputRoot VBox BBox Rect Text Button OnKey OnUpdate);

my %state = (result => 'pending');

my $ui = App {
        OnUpdate { frame_update(@_) };
        OnKey 'q' => sub ($app, $event) { $app->quit };

        Layer {
            Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
            BBox {
                VBox {
                    Text {} -text => 'Runnable 01: Button Action', -material => 'TITLE';
                    Text {} -text => 'Press Space on Run to launch the action.', -material => 'MUTED';
                    InputRoot {
                        Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                            $app->start_action('button-demo');
                        }, -margin => 0;
                    } -margin => 0;
                    Text {} -text => sub ($app, $renderer, $node) { 'Phase: ' . $app->action_phase }, -material => 'VALUE';
                    Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) . ' ' . progress_ratio($app) }, -material => 'TEXT';
                } -gap => 1;
            } -width => 44, -height => 10, -material => 'PANEL', -border_material => 'FRAME';
        } -x => -20, -y => 4;
    } -state => \%state,
      -setup => sub ($app, $runtime) {
          $app->state->{result} = 'terminal ' . $runtime->{cols} . 'x' . $runtime->{rows};
      },
      -action => sub ($app, $report, $label) {
          for my $step (1 .. 3) {
              $report->({ message => "running $label", current => $step, total => 3 });
              sleep_step(0.15);
          }
          return { label => $label, status => 'ok' };
      },
      -exit => sub ($app, $result) {
          print format_exit_report('01-button-action', $result);
          exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
      };

$ui->run(theme());

__END__
=pod

=head1 NAME

01-button-action.pl

=head1 DESCRIPTION

Minimal runnable lifecycle demo. Setup records terminal dimensions, a focused
button triggers the action worker, and the exit callback prints the result
bundle after the terminal is restored.

=cut
