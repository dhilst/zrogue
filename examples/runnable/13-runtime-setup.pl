use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use TML qw(App Layer InputRoot VBox BBox Rect Text Button OnKey OnUpdate);

my %state = (term => 'unknown');

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 13: Runtime Setup', -material => 'TITLE';
                Text {} -text => sub ($app, $renderer, $node) { 'Setup saw ' . $app->state->{term} }, -material => 'VALUE';
                InputRoot {
                    Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->start_action($app->state->{term}) }, -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'TEXT';
            } -gap => 1;
        } -width => 46, -height => 10, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -21, -y => 4;
} -state => \%state,
  -setup => sub ($app, $runtime) {
      $app->state->{term} = $runtime->{cols} . 'x' . $runtime->{rows};
  },
  -action => sub ($app, $report, $term) {
      $report->({ message => "using term $term" });
      sleep_step(0.15);
      return { term => $term };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('13-runtime-setup', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

13-runtime-setup.pl

=head1 DESCRIPTION

Focuses on the `-setup` contract by surfacing runtime terminal information in
both the UI and the final exit report.

=cut
