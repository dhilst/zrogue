use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step progress_message format_exit_report);
use ZTUI::TML qw(App Layer InputRoot FocusScope VBox BBox Rect Text FieldList Button ButtonRow OnKey OnUpdate);

my %state = (
    name => 'Ada',
    zone => 'North',
    safe => 1,
);
my @fields = (
    { label => 'Name', type => 'text', value_ref => \$state{name}, width => 12 },
    { label => 'Zone', type => 'text', value_ref => \$state{zone}, width => 12 },
    { label => 'Safe', type => 'toggle', value_ref => \$state{safe} },
);

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable 07: FieldList Form', -material => 'TITLE';
                Text {} -text => 'Use j/k inside the form. Use J to jump to Submit.', -material => 'MUTED';
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
                                    $app->start_action($app->state->{name}, $app->state->{zone}, $app->state->{safe});
                                }, -margin => 0;
                            } -margin => 0;
                        } -gap => 1;
                    } -margin => 0;
                } -margin => 0;
                Text {} -text => sub ($app, $renderer, $node) { 'Progress: ' . progress_message($app) }, -material => 'VALUE';
            } -gap => 1;
        } -width => 52, -height => 15, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -24, -y => 7;
} -state => \%state,
  -action => sub ($app, $report, $name, $zone, $safe) {
      $report->({ message => "submit $name" });
      sleep_step(0.20);
      return { name => $name, zone => $zone, safe => $safe ? 'yes' : 'no' };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('07-fieldlist-form', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());

__END__
=pod

=head1 NAME

07-fieldlist-form.pl

=head1 DESCRIPTION

Lifecycle form example using `FieldList` as the local editing domain and a
button row as the action trigger.

=cut
