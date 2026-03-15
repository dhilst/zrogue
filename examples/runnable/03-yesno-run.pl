use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use ZTUI::TML qw(App Layer InputRoot FocusScope VBox BBox Rect Text Button ButtonRow OnKey OnUpdate);

my %state = (choice => 'none');

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 03: Yes/No Runner', -material => 'TITLE';
                Text {} -text => 'Use j/k to pick Yes or No, then Space to launch.', -material => 'MUTED';
                InputRoot {
                    FocusScope {
                        ButtonRow {
                            Button {} -label => 'Yes', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                                $app->state->{choice} = 'yes';
                                $app->start_action('yes');
                            }, -margin => 0;
                            Button {} -label => 'No', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                                $app->state->{choice} = 'no';
                                $app->start_action('no');
                            }, -margin => 0;
                        } -margin => 0;
                    } -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Choice: ' . $app->state->{choice} }, -material => 'VALUE';
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'TEXT';
            } -gap => 1;
        } -width => 46, -height => 11, -material => 'PANEL', -border_material => 'HEAVY';
    } -x => -21, -y => 5;
} -state => \%state,
  -action => sub ($app, $report, $choice) {
      $report->({ message => "confirmed $choice" });
      sleep_step(0.20);
      return { choice => $choice };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('03-yesno-run', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

03-yesno-run.pl

=head1 DESCRIPTION

Runnable yes/no dialog that forwards the selected branch into the lifecycle
action and exits with the printed result bundle.

=cut
