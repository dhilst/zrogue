use v5.36;
use utf8;

use Carp qw(confess);
use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message progress_ratio format_exit_report parse_cli_options write_output_file);
use ZTUI::TML qw(App Layer InputRoot FocusScope VBox HBox BBox Rect Text TextField Toggle List TextViewport Button ButtonRow OnKey OnUpdate);

my $cli = parse_cli_options();
my $output_path = $cli->{output_path};
confess "-output is required for 20-full-lifecycle.pl"
    unless defined($output_path) && length($output_path);

my @targets = map { +{ label => $_ } } qw(Ruins Archive Tower Vault);
my @log = ('setup pending');
my %state = (
    codename => 'ASH',
    safe => 1,
    selected => 0,
    scroll => 0,
    runtime => 'unknown',
);

my $ui = App {
    OnUpdate {
        frame_update(@_);
        my ($app, $dt, @events) = @_;
        my $progress = $app->action_latest_progress;
        if (defined $progress && defined $progress->{message}) {
            push @log, $progress->{message} if !@log || $log[-1] ne $progress->{message};
        }
    };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 20: Full Lifecycle', -material => 'TITLE';
                Text {} -text => sub ($app, $renderer, $node) { 'Runtime: ' . $app->state->{runtime} }, -material => 'VALUE';
                Text {} -text => 'Edit on the left, review on the right, then Launch.', -material => 'MUTED';
                InputRoot {
                    FocusScope {
                        HBox {
                            VBox {
                                TextField {} -value_ref => \$state{codename}, -width => 12, -focused_material => 'FOCUS', -active_material => 'FOCUS', -margin => 0;
                                Toggle {} -label => 'Safe mode', -value_ref => \$state{safe}, -focused_material => 'FOCUS', -margin => 0;
                                List {}
                                    -items_ref => \@targets,
                                    -selected_index_ref => \$state{selected},
                                    -height => 4,
                                    -width => 16,
                                    -focused_material => 'FOCUS',
                                    -margin => 0;
                            } -gap => 1, -margin => 0;
                            VBox {
                                TextViewport {}
                                    -lines_ref => \@log,
                                    -scroll_ref => \$state{scroll},
                                    -width => 28,
                                    -height => 6,
                                    -focused_material => 'FOCUS',
                                    -margin => 0;
                                ButtonRow {
                                    Button {} -label => 'Launch', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                                        $app->start_action(
                                            $app->state->{codename},
                                            $targets[$app->state->{selected}]{label},
                                            $app->state->{safe},
                                        );
                                    }, -margin => 0;
                                } -margin => 0;
                            } -gap => 1, -margin => 0;
                        } -gap => 2, -margin => 0;
                    } -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Phase: ' . $app->action_phase . ' ' . progress_message($app) . ' ' . progress_ratio($app) }, -material => 'TEXT';
            } -gap => 1;
        } -width => 68, -height => 18, -material => 'PANEL_ALT', -border_material => 'HEAVY';
    } -x => -32, -y => 8;
} -state => \%state,
  -setup => sub ($app, $runtime) {
      $app->state->{runtime} = $runtime->{cols} . 'x' . $runtime->{rows};
      @log = ('setup ' . $app->state->{runtime});
  },
  -action => sub ($app, $report, $codename, $target, $safe) {
      my @phases = (
          "validate $codename",
          "route $target",
          $safe ? 'safe launch' : 'unsafe launch',
          'complete',
      );
      for my $idx (0 .. $#phases) {
          $report->({ message => $phases[$idx], current => $idx + 1, total => scalar @phases });
          sleep_step(0.12);
      }
      my $output = "launch:$codename:$target\n";
      return {
          codename => $codename,
          target => $target,
          safe => $safe ? 'yes' : 'no',
          output => $output,
      };
  },
  -exit => sub ($app, $result) {
      if (($result->{action_exit_code} // 1) == 0) {
          my $output = $result->{action_result}{output} // '';
          write_output_file($output_path, $output);
      }
      print format_exit_report('20-full-lifecycle', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

20-full-lifecycle.pl

=head1 DESCRIPTION

Comprehensive runnable example exercising setup, interactive editing, progress
streaming, output-file emission, terminal restoration, and exit reporting.

=head1 OPTIONS

=over 4

=item B<-output> I<PATH>

Required. Output file path for the launch payload.

=item B<-help>, B<-h>

Show brief usage.

=item B<-man>

Show full documentation.

=back

=cut
