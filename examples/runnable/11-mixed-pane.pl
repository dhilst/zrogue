use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use TML qw(App Layer InputRoot FocusScope VBox HBox BBox Rect Text TextField List TextViewport Button ButtonRow OnKey OnUpdate);

my %state = (code => 'ASH', selected => 0, scroll => 0);
my @targets = map { +{ label => $_ } } qw(Gate Lift Tower Vault);
my @notes = (
    'Left pane edits mission input.',
    'Right pane shows notes and launch controls.',
    'Use J/K to move between panes.',
);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 11: Mixed Pane', -material => 'TITLE';
                Text {} -text => 'Use j/k locally. Use J/K to jump between panes.', -material => 'MUTED';
                InputRoot {
                    FocusScope {
                        HBox {
                            VBox {
                                TextField {} -value_ref => \$state{code}, -width => 10, -focused_material => 'FOCUS', -active_material => 'FOCUS', -margin => 0;
                                List {}
                                    -items_ref => \@targets,
                                    -selected_index_ref => \$state{selected},
                                    -height => 4,
                                    -width => 14,
                                    -focused_material => 'FOCUS',
                                    -margin => 0;
                            } -gap => 1, -margin => 0;
                            VBox {
                                TextViewport {}
                                    -lines_ref => \@notes,
                                    -scroll_ref => \$state{scroll},
                                    -width => 24,
                                    -height => 4,
                                    -focused_material => 'FOCUS',
                                    -margin => 0;
                                ButtonRow {
                                    Button {} -label => 'Launch', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                                        $app->start_action($app->state->{code}, $targets[$app->state->{selected}]{label});
                                    }, -margin => 0;
                                } -margin => 0;
                            } -gap => 1, -margin => 0;
                        } -gap => 2, -margin => 0;
                    } -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 58, -height => 15, -material => 'PANEL_ALT', -border_material => 'HEAVY';
    } -x => -27, -y => 7;
} -state => \%state,
  -action => sub ($app, $report, $code, $target) {
      $report->({ message => "launch $code -> $target", current => 1, total => 2 });
      sleep_step(0.18);
      $report->({ message => "confirm $target", current => 2, total => 2 });
      return { code => $code, target => $target };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('11-mixed-pane', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

11-mixed-pane.pl

=head1 DESCRIPTION

Full mixed-dialog example using pane-local navigation, pane exit navigation,
and a launch action.

=cut
