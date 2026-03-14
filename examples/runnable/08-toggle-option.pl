use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use TML qw(App Layer InputRoot VBox BBox Rect Text Toggle Button OnKey OnUpdate);

my %state = (safe_mode => 1);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 08: Toggle Option', -material => 'TITLE';
                Text {} -text => 'Toggle the option, then move to Run with j.', -material => 'MUTED';
                InputRoot {
                    VBox {
                        Toggle {} -label => 'Safe mode', -value_ref => \$state{safe_mode}, -focused_material => 'FOCUS', -margin => 0;
                        Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                            $app->start_action($app->state->{safe_mode});
                        }, -margin => 0;
                    } -gap => 1, -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 44, -height => 11, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -20, -y => 5;
} -state => \%state,
  -action => sub ($app, $report, $safe_mode) {
      $report->({ message => $safe_mode ? 'safe mode' : 'unsafe mode' });
      sleep_step(0.20);
      return { safe_mode => $safe_mode ? 'enabled' : 'disabled' };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('08-toggle-option', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

08-toggle-option.pl

=head1 DESCRIPTION

Uses a `Toggle` value as an action argument and then exits through the restored
terminal.

=cut
