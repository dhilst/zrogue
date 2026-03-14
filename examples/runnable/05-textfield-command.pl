use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use TML qw(App Layer InputRoot VBox BBox Rect Text TextField Button OnKey OnUpdate);

my %state = (command => 'deploy');

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 05: TextField Command', -material => 'TITLE';
                Text {} -text => 'Enter edits the field. Space on Run starts the action.', -material => 'MUTED';
                InputRoot {
                    VBox {
                        TextField {} -value_ref => \$state{command}, -width => 16, -focused_material => 'FOCUS', -active_material => 'FOCUS', -margin => 0;
                        Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                            $app->start_action($app->state->{command});
                        }, -margin => 0;
                    } -gap => 1, -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 52, -height => 11, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -24, -y => 5;
} -state => \%state,
  -action => sub ($app, $report, $command) {
      $report->({ message => "queue $command" });
      sleep_step(0.20);
      return { command => $command, status => 'queued' };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('05-textfield-command', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

05-textfield-command.pl

=head1 DESCRIPTION

Shows a `TextField` feeding a runtime argument into the action callback.

=cut
