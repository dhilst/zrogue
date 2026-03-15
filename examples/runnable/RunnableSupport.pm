package RunnableSupport;
use v5.36;
use utf8;

use Carp qw(confess);
use Exporter qw(import);
use FindBin qw($Bin);
use Getopt::Long qw(GetOptionsFromArray);
use Pod::Usage qw(pod2usage);

use lib "$Bin/../../lib";
use lib "$Bin/../input";

use InputTheme;

our @EXPORT_OK = qw(
    theme
    frame_update
    sleep_step
    progress_message
    progress_ratio
    format_exit_report
    parse_cli_options
    write_output_file
);

sub theme() {
    return InputTheme::build_theme();
}

sub frame_update($app, $dt, @events) {
    my $state = $app->state;
    my $progress = $app->action_latest_progress // {};
    my $token = join "\x1f",
        $app->action_phase,
        ($progress->{message} // ''),
        (defined($progress->{current}) ? $progress->{current} : ''),
        (defined($progress->{total}) ? $progress->{total} : '');

    my $needs_render = !$state->{_bootstrapped};
    $state->{_bootstrapped} = 1;
    $needs_render = 1 if @events;
    $needs_render = 1 if $app->action_is_running;
    $needs_render = 1 if ($state->{_last_action_token} // '') ne $token;
    $state->{_last_action_token} = $token;

    $app->skip_render unless $needs_render;
    return;
}

sub sleep_step($seconds = 0.10) {
    select undef, undef, undef, $seconds;
    return;
}

sub progress_message($app) {
    my $progress = $app->action_latest_progress;
    return 'idle' unless defined $progress;
    return $progress->{message} // 'idle';
}

sub progress_ratio($app) {
    my $progress = $app->action_latest_progress;
    return '' unless defined $progress;
    return '' unless defined $progress->{current} && defined $progress->{total};
    return $progress->{current} . '/' . $progress->{total};
}

sub format_exit_report($label, $result) {
    my $lines = [
        "example=$label",
        "phase=" . ($result->{action_phase} // 'idle'),
        "exit_code=" . (defined($result->{action_exit_code}) ? $result->{action_exit_code} : ''),
    ];

    my $action_result = $result->{action_result};
    if (defined $action_result) {
        if (ref($action_result) eq 'HASH') {
            push @$lines, map {
                "result.$_=" . (defined($action_result->{$_}) ? $action_result->{$_} : '')
            } sort keys $action_result->%*;
        } else {
            push @$lines, "result=$action_result";
        }
    }

    push @$lines, "stdout=" . ($result->{action_stdout} // '');
    push @$lines, "stderr=" . ($result->{action_stderr} // '');
    return join "\n", @$lines, '';
}

sub parse_cli_options($argv_ref = \@ARGV) {
    confess "parse_cli_options expects an array ref"
        unless defined($argv_ref) && ref($argv_ref) eq 'ARRAY';

    my $help = 0;
    my $man = 0;
    my $output_path;

    my $ok = GetOptionsFromArray(
        $argv_ref,
        'output=s' => \$output_path,
        'help|h'   => \$help,
        'man'      => \$man,
    );

    pod2usage(-exitval => 2, -verbose => 1) unless $ok;
    pod2usage(-exitval => 0, -verbose => 1) if $help;
    pod2usage(-exitval => 0, -verbose => 2) if $man;
    pod2usage(-exitval => 2, -verbose => 1, -message => 'Unexpected positional arguments')
        if @$argv_ref;

    return {
        output_path => $output_path,
    };
}

sub write_output_file($path, $content) {
    confess "output path is required"
        unless defined($path) && !ref($path) && length($path);
    confess "output content must be defined"
        unless defined $content;

    open(my $fh, '>:encoding(UTF-8)', $path)
        or confess "unable to open output path '$path': $!";
    print {$fh} $content
        or confess "unable to write output path '$path': $!";
    close($fh)
        or confess "unable to close output path '$path': $!";
    return;
}

1;
