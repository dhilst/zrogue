use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use ZTUI::TML qw(App Layer InputRoot VBox BBox Rect Text List Button OnKey OnUpdate);

my @targets = map { +{ label => $_ } } qw(Alpha Bravo Charlie Delta);
my %state = (selected => 0);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 06: List Target', -material => 'TITLE';
                Text {} -text => 'Pick a target with j/k. J leaves the list for Run.', -material => 'MUTED';
                InputRoot {
                    VBox {
                        List {}
                            -items_ref => \@targets,
                            -selected_index_ref => \$state{selected},
                            -height => 4,
                            -width => 14,
                            -focused_material => 'FOCUS',
                            -margin => 0;
                        Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                            $app->start_action($targets[$app->state->{selected}]{label});
                        }, -margin => 0;
                    } -gap => 1, -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 44, -height => 13, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -20, -y => 6;
} -state => \%state,
  -action => sub ($app, $report, $target) {
      for my $step (1 .. 3) {
          $report->({ message => "target $target", current => $step, total => 3 });
          sleep_step(0.12);
      }
      return { target => $target };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('06-list-target', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

06-list-target.pl

=head1 DESCRIPTION

Demonstrates a list-based chooser feeding the action payload through a separate
run button.

=cut
