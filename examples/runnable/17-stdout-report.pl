use v5.36;
use utf8;

use Carp qw(confess);
use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report parse_cli_options write_output_file);
use TML qw(App Layer InputRoot VBox BBox Rect Text Button OnKey OnUpdate);

my $cli = parse_cli_options();
my $output_path = $cli->{output_path};
confess "-output is required for 17-stdout-report.pl"
    unless defined($output_path) && length($output_path);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 17: File Output', -material => 'TITLE';
                Text {} -text => 'On success, writes payload to -output path.', -material => 'MUTED';
                InputRoot {
                    Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->start_action('stdout') }, -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 62, -height => 10, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -29, -y => 4;
} -state => {},
  -action => sub ($app, $report, $label) {
      $report->({ message => "emit $label" });
      sleep_step(0.12);
      return {
          label => $label,
          output => "payload:$label\n",
      };
  },
  -exit => sub ($app, $result) {
      if (($result->{action_exit_code} // 1) == 0) {
          my $output = $result->{action_result}{output} // '';
          write_output_file($output_path, $output);
      }
      print format_exit_report('17-stdout-report', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

17-stdout-report.pl

=head1 DESCRIPTION

Produces an output payload and writes it to the file path provided via
C<-output> when the action succeeds.

=head1 OPTIONS

=over 4

=item B<-output> I<PATH>

Required. Output file path for the payload.

=item B<-help>, B<-h>

Show brief usage.

=item B<-man>

Show full documentation.

=back

=cut
