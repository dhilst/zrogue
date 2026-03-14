use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use TML qw(App Layer InputRoot FocusScope VBox BBox Rect Text FieldList Button ButtonRow OnKey OnUpdate);

my %state = (
    name => 'Nova',
    region => 'West',
);
my @fields = (
    { label => 'Name', type => 'text', value_ref => \$state{name}, width => 12 },
    { label => 'Region', type => 'text', value_ref => \$state{region}, width => 12 },
);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 19: Form Confirm', -material => 'TITLE';
                Text {} -text => 'Edit the form, then confirm with the Submit button.', -material => 'MUTED';
                InputRoot {
                    FocusScope {
                        VBox {
                            FieldList {}
                                -fields => \@fields,
                                -focused_material => 'FOCUS',
                                -active_material => 'FOCUS',
                                -material => 'TEXT',
                                -margin => 0;
                            ButtonRow {
                                Button {} -label => 'Submit', -focused_material => 'FOCUS', -on_press => sub ($app, $node) {
                                    $app->start_action($app->state->{name}, $app->state->{region});
                                }, -margin => 0;
                                Button {} -label => 'Quit', -focused_material => 'FOCUS', -on_press => sub ($app, $node) { $app->quit }, -margin => 0;
                            } -margin => 0;
                        } -gap => 1;
                    } -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 52, -height => 14, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -24, -y => 6;
} -state => \%state,
  -action => sub ($app, $report, $name, $region) {
      $report->({ message => "submit $name/$region" });
      sleep_step(0.18);
      return { name => $name, region => $region };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('19-form-confirm', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

19-form-confirm.pl

=head1 DESCRIPTION

Variation on the runnable form flow with an explicit quit branch alongside the
submit path.

=cut
