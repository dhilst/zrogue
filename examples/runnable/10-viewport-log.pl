use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use TML qw(App Layer InputRoot VBox BBox Rect Text TextViewport Button OnKey OnUpdate);

my @lines = ('pending');

my $ui = App {
    OnUpdate {
        frame_update(@_);
        my ($app, $dt, @events) = @_;
        my $progress = $app->action_latest_progress;
        if (defined $progress && defined $progress->{message}) {
            my $msg = $progress->{message};
            push @lines, $msg if !@lines || $lines[-1] ne $msg;
        }
    };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 10: Viewport Log', -material => 'TITLE';
                Text {} -text => 'Start the action and watch progress messages accumulate.', -material => 'MUTED';
                InputRoot {
                    VBox {
                        TextViewport {}
                            -lines_ref => \@lines,
                            -width => 28,
                            -height => 5,
                            -focused_material => 'FOCUS',
                            -margin => 0;
                        Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->start_action('log') }, -margin => 0;
                    } -gap => 1;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Latest: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 52, -height => 14, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -24, -y => 6;
} -state => {},
  -action => sub ($app, $report, $label) {
      for my $phase (qw(connect upload verify complete)) {
          $report->({ message => "$label:$phase" });
          sleep_step(0.12);
      }
      return { label => $label };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('10-viewport-log', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

10-viewport-log.pl

=head1 DESCRIPTION

Demonstrates a `TextViewport` that mirrors progress messages emitted by the
forked action callback.

=cut
