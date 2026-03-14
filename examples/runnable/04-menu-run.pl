use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use TML qw(App Layer InputRoot FocusScope VBox BBox Rect Text Button ButtonRow List OnKey OnUpdate);

my @items = map { +{ label => $_ } } qw(Scan Repair Archive Retreat);
my %state = (selected => 0);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 04: Menu Runner', -material => 'TITLE';
                Text {} -text => 'Use j/k inside the list. Use J to jump to OK.', -material => 'MUTED';
                InputRoot {
                    FocusScope {
                        VBox {
                            List {}
                                -items_ref => \@items,
                                -selected_index_ref => \$state{selected},
                                -height => 4,
                                -width => 16,
                                -focused_material => 'FOCUS',
                                -margin => 0;
                            ButtonRow {
                                Button {} -label => 'OK', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                                    $app->start_action($items[$app->state->{selected}]{label});
                                }, -margin => 0;
                            } -margin => 0;
                        } -gap => 1;
                    } -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 44, -height => 13, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -20, -y => 6;
} -state => \%state,
  -action => sub ($app, $report, $selection) {
      $report->({ message => "dispatching $selection", current => 1, total => 2 });
      sleep_step(0.15);
      $report->({ message => "completed $selection", current => 2, total => 2 });
      return { selection => $selection };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('04-menu-run', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

04-menu-run.pl

=head1 DESCRIPTION

Combines a local list navigation domain with `J`-based exit navigation into a
button row that starts the action worker.

=cut
