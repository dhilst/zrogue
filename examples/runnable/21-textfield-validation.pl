use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use TML qw(App Layer InputRoot VBox BBox Rect Text TextField Button OnKey OnUpdate);

my %state = (
    command => 'deploy',
    command_error => undef,
);
my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 21: Validated TextField', -material => 'TITLE';
                Text {} -text => 'Type lowercase command words, Enter to save, Run to execute.', -material => 'MUTED';
                InputRoot {
                    VBox {
                        TextField {}
                            -value_ref => \$state{command},
                            -validate => sub ($app, $renderer, $node, $candidate) {
                                return $candidate =~ /^[a-z]+$/;
                            },
                            -on_invalid => sub ($app, $node, $candidate) {
                                $app->state->{command_error} = "command must be lowercase letters";
                            },
                            -on_change => sub ($app, $node, $new_value) {
                                delete $app->state->{command_error};
                            },
                            -on_submit => sub ($app, $node, $new_value) {
                                delete $app->state->{command_error};
                            },
                            -width => 18,
                            -focused_material => 'FOCUS',
                            -active_material => 'FOCUS',
                            -margin => 0;
                        Button {} -label => 'Run', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                            $app->start_action($app->state->{command});
                        }, -margin => 0;
                    } -gap => 1, -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) {
                    return $app->state->{command_error}
                        ? "error: $app->state->{command_error}"
                        : 'command looks valid';
                }, -material => sub ($app, $renderer, $node) {
                    return $app->state->{command_error} ? 'DANGER' : 'VALUE';
                };
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 52, -height => 12, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -24, -y => 4;
} -state => \%state,
  -action => sub ($app, $report, $command) {
      $report->({ message => "queue $command" });
      sleep_step(0.20);
      return { command => $command, status => 'queued' };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('21-textfield-validation', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

21-textfield-validation.pl

=head1 DESCRIPTION

Demonstrates TextField validation via a predicate callback plus user-visible invalid
submission feedback through an on-invalid state message.

=cut
