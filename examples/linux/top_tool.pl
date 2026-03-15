use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../../lib";
use lib "$Bin";
use lib "$Bin/data";
use lib "$Bin/../runnable";

use RunnableSupport qw(theme);
use MetricSampler;
use ZTUI::GradientHelper;
use ZTUI::MaterialMapper;
use ZTUI::TerminalStyle;
use ZTUI::Theme;
use ZTUI::TML qw(App Layer VBox HBox BBox Rect Text TextViewport OnUpdate OnKey);
use List::Util qw(sum);
use Getopt::Long qw(GetOptionsFromArray);
use Carp qw(confess);
use Cwd qw(abs_path);
use POSIX qw(sysconf _SC_PAGESIZE _SC_CLK_TCK);
use ZTUI::SGR qw(ATTR_BOLD);
use Pod::Usage qw(pod2usage);

use constant BAR_GRADIENT_STEPS => 12;
use constant TOP_BAR_START => 0x2ecc71;
use constant TOP_BAR_END => 0xff4b4b;
use constant SORT_KEYS => [qw(cpu memory disk network)];
use constant DISK_SCALE => 15 * 1024 * 1024;    # 15 MB/s expected
use constant NETWORK_SCALE => 8 * 1024 * 1024;  # 8 MB/s expected
use constant TOP_PANEL_LINES => 8;
use constant CPU_MEM_MIN_LINES => 7;
use constant SAMPLE_INTERVAL => 1; # seconds
use constant PAGE_SIZE => (sysconf(_SC_PAGESIZE) // 4096);
use constant CLK_TCK => (sysconf(_SC_CLK_TCK) // 100);

my $bar_gradient = ZTUI::GradientHelper::new(
    angle_deg   => 0,
    start_color => TOP_BAR_START,
    end_color   => TOP_BAR_END,
);

my $base_theme = theme();
my $base_material_mapper = $base_theme->{material_mapper};
my $base_border_mapper  = $base_theme->{border_mapper};
my $fallback_style = $base_theme->{fallback_material_style};

my $top_tool_theme = ZTUI::Theme::new(
    -material_mapper => ZTUI::MaterialMapper::from_callback(sub ($material) {
        if ($material eq 'SORT_ACTIVE') {
            my $base = $base_material_mapper->lookup('TEXT') // $fallback_style;
            my ($fg, $bg);
            if (ref($base) eq 'ZTUI::TerminalStyle') {
                $fg = $base->fg;
                $bg = $base->bg;
            } elsif (ref($base) eq 'HASH') {
                $fg = $base->{-fg};
                $bg = $base->{-bg};
            }
            my %style = (-attrs => ATTR_BOLD);
            $style{-fg} = $fg if defined $fg;
            $style{-bg} = $bg if defined $bg;
            return ZTUI::TerminalStyle::new(%style);
        }
        if ($material =~ /^TOPBAR_(\d+)_(\d+)$/) {
            my $width = $1;
            my $pos = $2;
            my $safe_width = $width > 0 ? $width : 1;
            my $color = $bar_gradient->color_at_local($pos, 0, $safe_width, 1);
            return { -fg => $color };
        }

        my $style = $base_material_mapper->lookup($material);
        return $style // $fallback_style;
    }),
    -border_mapper => $base_border_mapper,
);

my $sampler = MetricSampler->new;
my $initial_snapshot = $sampler->snapshot;
my @startup_argv = @ARGV;
my $script_path = abs_path($0) // $0;

my $refresh_rate = SAMPLE_INTERVAL;
my $help = 0;
GetOptionsFromArray(
    \@ARGV,
    'refresh-rate=f' => \$refresh_rate,
    'help|h' => \$help,
) or pod2usage(2);
pod2usage(-verbose => 2) if $help;
$refresh_rate = SAMPLE_INTERVAL if !defined($refresh_rate) || $refresh_rate <= 0;

my $state = {
    snapshot     => $initial_snapshot,
    disk_order   => 'read',
    net_order    => 'rx',
    disk_space   => [],
    help_visible => 0,
    help_scroll  => 0,
    process_sort => 'cpu',
    sort_idx     => 0,
    next_sample  => 0,
    process_rows => undef,
    process_raw  => {},
    process_tick => 0,
};

my @help_lines = (
    'Top Tool Help',
    '',
    'Overview:',
    '  Full-screen panel layout with per-core CPU bars, memory summary,',
    '  disk I/O, disk space, network I/O, and a process table.',
    '',
    'Panels:',
    '  CPU & Memory:',
    '    - Two-column CPU bar list, showing usage per core.',
    '    - Memory summary line and usage bar (below CPU list).',
    '',
    '  Disk I/O:',
    '    - Read/write bars show aggregate activity.',
    '    - Per-device list below, ordered by D toggle (read/write).',
    '',
    '  Disk Space:',
    '    - Filesystem usage from df -PT -B1.',
    '    - Columns: Filesystem, Type, Mount, Use%, Usage/Total.',
    '',
    '  Network I/O:',
    '    - RX/TX bars show aggregate activity.',
    '    - Per-interface list below, ordered by N toggle (rx/tx).',
    '',
    '  Processes:',
    '    - Sorted by CPU, memory, disk, or network.',
    '    - Disk sort respects D toggle (read/write).',
    '    - Network sort respects N toggle (rx/tx).',
    '',
    'Keybinds:',
    '  q     quit (or close help when help is open)',
    '  H     toggle help overlay',
    '  Tab   cycle sort key',
    '  K     reverse sort order',
    '  D     disk order (read/write)',
    '  N     network order (rx/tx)',
    '  j/k   scroll help',
    '',
    'Signals:',
    '  SIGUSR1 restarts the process via exec.',
);

$SIG{USR1} = sub {
    exec $^X, $script_path, @startup_argv or confess "exec restart failed: $!";
};

sub read_process_iostats ($pid) {
    my $path = "/proc/$pid/io";
    return {} unless -r $path;
    open my $fh, '<', $path or return {};
    my %values;
    while (my $line = <$fh>) {
        if ($line =~ /^(\w+):\s+(\d+)/) {
            $values{$1} = 0 + $2;
        }
    }
    close $fh;
    return \%values;
}

sub read_process_snapshot_live ($state, $delta_t) {
    my $proc_root = '/proc';
    opendir my $dir, $proc_root or confess "proc root: $!";
    my @pids = grep {/^\d+$/} readdir $dir;
    closedir $dir;

    my $prev = $state->{process_raw} // {};
    my %next_raw;
    my @rows;

    foreach my $pid (@pids) {
        my $path = "$proc_root/$pid/stat";
        next unless -r $path;
        open my $fh, '<', $path or next;
        my $line = <$fh>;
        close $fh;
        next unless defined $line;
        next unless $line =~ /^\s*(\d+)\s+\((.*?)\)\s+(.*)$/;
        my $raw_pid = 0 + $1;
        my $name = $2 // 'unknown';
        my @fields = split /\s+/, $3;
        my $utime = $fields[11] // 0;
        my $stime = $fields[12] // 0;
        my $rss = $fields[21] // 0;
        my $io = read_process_iostats($raw_pid);
        my $record = {
            pid   => $raw_pid,
            name  => $name,
            utime => $utime,
            stime => $stime,
            rss   => $rss,
            io    => $io,
        };
        $next_raw{$raw_pid} = $record;

        my $prev_entry = $prev->{$raw_pid};
        my $cpu_time = 0;
        my $disk_io = 0;
        my $disk_read = 0;
        my $disk_write = 0;
        if ($prev_entry && $delta_t > 0) {
            my $delta_cpu = (($utime + $stime) - (($prev_entry->{utime} // 0) + ($prev_entry->{stime} // 0)));
            $cpu_time = CLK_TCK ? ($delta_cpu / CLK_TCK) : 0;
            my $curr_read = $io->{read_bytes} // 0;
            my $curr_write = $io->{write_bytes} // 0;
            my $prev_read = $prev_entry->{io}{read_bytes} // 0;
            my $prev_write = $prev_entry->{io}{write_bytes} // 0;
            my $delta_read = $curr_read - $prev_read;
            my $delta_write = $curr_write - $prev_write;
            $disk_read = $delta_t > 0 ? ($delta_read / $delta_t) : 0;
            $disk_write = $delta_t > 0 ? ($delta_write / $delta_t) : 0;
            $disk_io = $disk_read + $disk_write;
        }

        push @rows, {
            pid        => $raw_pid,
            name       => $name,
            cpu_time   => $cpu_time < 0 ? 0 : $cpu_time,
            memory     => ($rss // 0) * PAGE_SIZE,
            disk_io    => $disk_io < 0 ? 0 : $disk_io,
            disk_read  => $disk_read < 0 ? 0 : $disk_read,
            disk_write => $disk_write < 0 ? 0 : $disk_write,
            network_io => 0,
            network_rx => 0,
            network_tx => 0,
        };
    }

    $state->{process_raw} = \%next_raw;
    return \@rows;
}

sub _unescape_mount($value) {
    $value =~ s/\\040/ /g;
    $value =~ s/\\011/\t/g;
    $value =~ s/\\012/\n/g;
    $value =~ s/\\134/\\/g;
    return $value;
}

sub read_disk_space_snapshot () {
    my %skip_fs = map { $_ => 1 } qw(
        proc sysfs devtmpfs tmpfs cgroup cgroup2 pstore autofs mqueue hugetlbfs
        tracefs fusectl debugfs securityfs configfs devpts rpc_pipefs binfmt_misc
        nsfs overlay squashfs
    );
    open my $fh, '-|', 'df', '-PT', '-B1' or return [];
    my $header = <$fh>;
    my @rows;
    while (my $line = <$fh>) {
        chomp $line;
        next unless length $line;
        my @fields = split /\s+/, $line, 7;
        next unless @fields >= 7;
        my ($fs, $fstype, $total, $used, $avail, $usep, $mnt) = @fields;
        next if $skip_fs{$fstype};
        $mnt = _unescape_mount($mnt // '');
        next if $mnt =~ m{^/(proc|sys|dev)\b};
        $total = 0 + ($total // 0);
        $used = 0 + ($used // 0);
        $avail = 0 + ($avail // 0);
        my $percent = $total ? ($used / $total) * 100 : 0;
        push @rows, {
            fs => $fs,
            type => $fstype,
            mount => $mnt,
            total => $total,
            used => $used,
            avail => $avail,
            percent => $percent,
        };
    }
    close $fh;
    @rows = sort { $b->{percent} <=> $a->{percent} } @rows;
    return \@rows;
}

sub render_disk_space ($state) {
    my $rows = $state->{disk_space} // [];
    return 'collecting disk space...' unless @$rows;
    my $text = sprintf "%-12s %-8s %-10s %6s %13s\n", 'Filesystem', 'Type', 'Mount', 'Use%', 'Usage/Total';
    my $limit = @$rows < 3 ? @$rows : 3;
    for my $idx (0 .. $limit - 1) {
        my $row = $rows->[$idx];
        my $percent = sprintf '%5.1f', $row->{percent} // 0;
        my $used_g = sprintf '%5.1fG', ($row->{used} // 0) / (1024 * 1024 * 1024);
        my $total_g = sprintf '%5.1fG', ($row->{total} // 0) / (1024 * 1024 * 1024);
        my $mount = sprintf '%-10s', $row->{mount} // '?';
        my $fs = sprintf '%-12s', $row->{fs} // '?';
        my $type = sprintf '%-8s', $row->{type} // '?';
        $text .= sprintf "%s %s %s %5s%% %s/%s\n", $fs, $type, $mount, $percent, $used_g, $total_g;
    }
    $text .= "  + " . (@$rows - $limit) . " more\n" if @$rows > $limit;
    return $text;
}

sub bar_width_for_panel ($renderer, $overhead = 20) {
    my $cols = defined $renderer && $renderer->can('width') ? $renderer->width : 80;
    my $width = int($cols - $overhead);
    return $width < 8 ? 8 : $width;
}

sub bar_width_for_half_panel ($renderer, $overhead = 18) {
    my $cols = defined $renderer && $renderer->can('width') ? $renderer->width : 80;
    my $width = int(($cols / 2) - $overhead);
    return $width < 8 ? 8 : $width;
}

sub cpu_row_count_from_snapshot ($state) {
    my $rows = $state->{snapshot} && $state->{snapshot}->{cpu} ? scalar(@{ $state->{snapshot}->{cpu} }) : 0;
    return int(($rows + 1) / 2);
}

sub cpu_core_count_from_snapshot ($state) {
    my $snap = $state->{snapshot};
    if ($snap && $snap->{cpu} && ref $snap->{cpu} eq 'ARRAY') {
        return scalar @{ $snap->{cpu} };
    }
    my $cores = $snap && $snap->{raw} && $snap->{raw}{cpu} && $snap->{raw}{cpu}{cores};
    return ref $cores eq 'HASH' ? scalar(keys %$cores) : 0;
}

sub cpu_memory_panel_height ($state, $renderer) {
    my $rows = defined $renderer && $renderer->can('height') ? int($renderer->height // 0) : 0;
    my $max_rows = int($rows * 0.25);
    $max_rows = 1 unless $max_rows > 0;
    my $cpu_rows = cpu_row_count_from_snapshot($state);
    my $needed = CPU_MEM_MIN_LINES + $cpu_rows;
    my $height = $needed < 1 ? CPU_MEM_MIN_LINES : $needed;
    $height = $max_rows if $height > $max_rows;
    return $height < 1 ? 1 : $height;
}

sub panel_top_height () {
    return TOP_PANEL_LINES;
}

sub process_panel_height ($state, $renderer) {
    my $rows = defined $renderer && $renderer->can('height') ? int($renderer->height // 0) : 0;
    my $reserved = panel_top_height() * 2;
    $reserved += cpu_memory_panel_height($state, $renderer);
    $reserved += 1;
    my $remaining = $rows - $reserved;
    return $remaining > 0 ? $remaining : 1;
}

sub topbar_material_name ($bar_width, $segment_idx) {
    return "TOPBAR_${bar_width}_${segment_idx}";
}

sub bar_segment_text_and_position ($percent, $bar_width, $segment_idx, $segments = BAR_GRADIENT_STEPS) {
    $percent //= 0;
    $bar_width = int($bar_width);
    $bar_width = 0 if $bar_width < 0;
    $segments = int($segments);
    $segments = 1 if $segments < 1;

    my $seg_start = int($bar_width * $segment_idx / $segments);
    my $seg_end = int($bar_width * ($segment_idx + 1) / $segments);
    $seg_end = $bar_width if $segment_idx == $segments - 1;
    my $seg_width = $seg_end - $seg_start;
    return ('', -1, $bar_width) if $seg_width <= 0;

    my $filled = int(($percent / 100) * $bar_width + 0.5);
    $filled = 0 if $filled < 0;
    $filled = $bar_width if $filled > $bar_width;

    my $segment_fill = $filled > $seg_end ? $seg_width : $filled > $seg_start ? $filled - $seg_start : 0;
    my $segment_empty = $seg_width - $segment_fill;
    my $text = ('█' x $segment_fill) . (' ' x $segment_empty);

    my $material_pos = int(($seg_start + $seg_end) / 2);
    return ($text, $segment_fill > 0 ? $material_pos : -1, $bar_width);
}

sub build_gradient_bar ($percent_cb, $bar_width_cb) {
    HBox {
        Text {} -text => '[', -material => 'TEXT', -margin => 0;
        for my $seg (0 .. BAR_GRADIENT_STEPS - 1) {
            Text {} -text => sub {
                my ($app, $renderer, $node) = @_;
                my $percent = $percent_cb->();
                my ($text) = bar_segment_text_and_position($percent, $bar_width_cb->($renderer), $seg);
                return $text;
            }, -material => sub {
                my ($app, $renderer, $node) = @_;
                my $percent = $percent_cb->();
                my ($text, $material_pos, $bar_width) = bar_segment_text_and_position($percent, $bar_width_cb->($renderer), $seg);
                return topbar_material_name($bar_width, $material_pos) if $material_pos >= 0;
                return $text =~ /\S/ ? topbar_material_name($bar_width, $seg) : 'TEXT';
            }, -margin => 0;
        }
        Text {} -text => ']', -material => 'TEXT', -margin => 0;
    } -gap => 0, -margin => 0;
}

sub cpu_entry_percent ($state, $idx) {
    my $rows = $state->{snapshot} && $state->{snapshot}->{cpu} ? $state->{snapshot}->{cpu} : [];
    return 0 unless $idx >= 0 && $idx <= $#$rows;
    return $rows->[$idx]->{usage} // 0;
}

sub cpu_entry_label ($state, $idx) {
    my $rows = $state->{snapshot} && $state->{snapshot}->{cpu} ? $state->{snapshot}->{cpu} : [];
    return '                ' unless $idx >= 0 && $idx <= $#$rows;
    my $row = $rows->[$idx];
    my $usage = sprintf '%5.1f', $row->{usage} // 0;
    my $id = sprintf '%-5s', $row->{id} // 'cpu?';
    return sprintf '%s %5s%% ', $id, $usage;
}

sub render_cpu_entry ($state, $idx, $bar_width_cb) {
    HBox {
        Text {} -text => sub { cpu_entry_label($state, $idx) }, -material => 'TEXT', -margin => 0;
        build_gradient_bar(
            sub { cpu_entry_percent($state, $idx) },
            $bar_width_cb,
        );
    } -gap => 0, -margin => 0;
}

sub summarize_iostat_payload ($state, $key, $order) {
    my $snap = $state->{snapshot};
    return {
        read_bytes => 0,
        write_bytes => 0,
        rx_bytes => 0,
        tx_bytes => 0,
        percent_read => 0,
        percent_write => 0,
        percent_rx => 0,
        percent_tx => 0,
        entries => [],
    } unless $snap && $snap->{$key};

    my $total_read = 0;
    my $total_write = 0;
    my $total_rx = 0;
    my $total_tx = 0;
    for my $entry (values %{ $snap->{$key} }) {
        $total_read += $entry->{read_bytes} // 0;
        $total_write += $entry->{write_bytes} // 0;
        $total_rx += $entry->{rx_bytes} // 0;
        $total_tx += $entry->{tx_bytes} // 0;
    }

    my $scale = $key eq 'disk' ? DISK_SCALE : NETWORK_SCALE;
    my $percent_read = $scale ? int(($total_read / $scale) * 100) : 0;
    my $percent_write = $scale ? int(($total_write / $scale) * 100) : 0;
    my $percent_rx = $scale ? int(($total_rx / $scale) * 100) : 0;
    my $percent_tx = $scale ? int(($total_tx / $scale) * 100) : 0;
    $percent_read = 0 if $percent_read < 0;
    $percent_read = 100 if $percent_read > 100;
    $percent_write = 0 if $percent_write < 0;
    $percent_write = 100 if $percent_write > 100;
    $percent_rx = 0 if $percent_rx < 0;
    $percent_rx = 100 if $percent_rx > 100;
    $percent_tx = 0 if $percent_tx < 0;
    $percent_tx = 100 if $percent_tx > 100;

    my @entries = sort {
        my $a_metric = 0;
        my $b_metric = 0;
        if ($key eq 'disk') {
            $a_metric = $order eq 'write' ? ($snap->{$key}{$a}{write_bytes} // 0) : ($snap->{$key}{$a}{read_bytes} // 0);
            $b_metric = $order eq 'write' ? ($snap->{$key}{$b}{write_bytes} // 0) : ($snap->{$key}{$b}{read_bytes} // 0);
        } else {
            $a_metric = $order eq 'tx' ? ($snap->{$key}{$a}{tx_bytes} // 0) : ($snap->{$key}{$a}{rx_bytes} // 0);
            $b_metric = $order eq 'tx' ? ($snap->{$key}{$b}{tx_bytes} // 0) : ($snap->{$key}{$b}{rx_bytes} // 0);
        }
        $b_metric <=> $a_metric;
    } keys %{ $snap->{$key} };

    return {
        read_bytes => $total_read,
        write_bytes => $total_write,
        rx_bytes => $total_rx,
        tx_bytes => $total_tx,
        percent_read => $percent_read,
        percent_write => $percent_write,
        percent_rx => $percent_rx,
        percent_tx => $percent_tx,
        entries => \@entries,
        kind => $key,
    };
}

sub summarize_iostat ($state, $key) {
    my $order = $key eq 'disk' ? ($state->{disk_order} // 'read') : ($state->{net_order} // 'rx');
    my $payload = summarize_iostat_payload($state, $key, $order);
    return 'collecting I/O data...' unless $payload->{entries};
    my $snap = $state->{snapshot};

    my $text = '';
    my @entries = $payload->{entries}->@*;
    my $max_lines = @entries < 3 ? @entries : 3;
    for my $i (0 .. $max_lines - 1) {
        my $name = $entries[$i] // '';
        my $entry = $snap->{$key}{$name} // {};
        if ($key eq 'disk') {
            my $read = sprintf '%.1f', ($entry->{read_bytes} // 0) / 1024;
            my $write = sprintf '%.1f', ($entry->{write_bytes} // 0) / 1024;
            $text .= sprintf "  %-10s R:%7sK W:%7sK\n", $name, $read, $write;
        } else {
            my $rx = sprintf '%.1f', ($entry->{rx_bytes} // 0) / 1024;
            my $tx = sprintf '%.1f', ($entry->{tx_bytes} // 0) / 1024;
            $text .= sprintf "  %-10s RX:%7sK TX:%7sK\n", $name, $rx, $tx;
        }
    }

    $text .= "  + " . (@entries - $max_lines) . " more\n" if @entries > $max_lines;
    $text = "  no active devices\n" unless length $text;
    return $text;
}

sub memory_percent ($state) {
    return $state->{snapshot}->{memory}->{percent} // 0 if $state->{snapshot} && $state->{snapshot}->{memory};
    return 0;
}

sub memory_summary_line ($state) {
    my $snap = $state->{snapshot};
    return 'collecting memory data...' unless $snap && $snap->{memory};
    my $mem = $snap->{memory};
    my $percent = sprintf '%5.1f', $mem->{percent} // 0;
    my $used = sprintf '%.1f', ($mem->{used} // 0) / (1024 * 1024);
    my $total = sprintf '%.1f', ($mem->{total} // 0) / (1024 * 1024);
    return sprintf "Memory: %s%% (%sM / %sM)", $percent, $used, $total;
}

sub disk_summary_title ($state) {
    my $payload = summarize_iostat_payload($state, 'disk', $state->{disk_order} // 'read');
    return 'Disk I/O' if (($payload->{read_bytes} // 0) + ($payload->{write_bytes} // 0)) == 0;
    return sprintf 'Disk I/O: R:%7.1fK W:%7.1fK', $payload->{read_bytes} / 1024, $payload->{write_bytes} / 1024;
}

sub network_summary_title ($state) {
    my $payload = summarize_iostat_payload($state, 'network', $state->{net_order} // 'rx');
    return 'Network I/O' if (($payload->{rx_bytes} // 0) + ($payload->{tx_bytes} // 0)) == 0;
    return sprintf 'Network I/O: RX:%7.1fK TX:%7.1fK', $payload->{rx_bytes} / 1024, $payload->{tx_bytes} / 1024;
}

sub bar_width_for_cpu_rows () {
    return sub ($renderer) {
        my $available = bar_width_for_panel($renderer, 34);
        my $per_col = int($available / 2);
        my $bar_room = $per_col - 15;
        return $bar_room >= 10 ? $bar_room : 10;
    }
}

sub cpu_display_pairs ($state) {
    return int((cpu_core_count_from_snapshot($state) + 1) / 2);
}

sub help_bar_parts ($state) {
    return (
        { text => 'Keys: q quit | H help | Tab sort | K reverse | D disk ', material => 'MUTED' },
        { text => 'read', material => sub {
            return (($state->{disk_order} // 'read') eq 'read') ? 'SORT_ACTIVE' : 'MUTED';
        }},
        { text => '/', material => 'MUTED' },
        { text => 'write', material => sub {
            return (($state->{disk_order} // 'read') eq 'write') ? 'SORT_ACTIVE' : 'MUTED';
        }},
        { text => ' | N net ', material => 'MUTED' },
        { text => 'rx', material => sub {
            return (($state->{net_order} // 'rx') eq 'rx') ? 'SORT_ACTIVE' : 'MUTED';
        }},
        { text => '/', material => 'MUTED' },
        { text => 'tx', material => sub {
            return (($state->{net_order} // 'rx') eq 'tx') ? 'SORT_ACTIVE' : 'MUTED';
        }},
    );
}

sub toggle_help ($state) {
    $state->{help_visible} = $state->{help_visible} ? 0 : 1;
    $state->{help_scroll} = 0 if $state->{help_visible};
}

sub toggle_disk_order ($state) {
    $state->{disk_order} = ($state->{disk_order} // 'read') eq 'write' ? 'read' : 'write';
}

sub toggle_network_order ($state) {
    $state->{net_order} = ($state->{net_order} // 'rx') eq 'tx' ? 'rx' : 'tx';
}

sub cycle_sort ($state, $direction = 1) {
    my $keys = SORT_KEYS;
    my $idx = $state->{sort_idx} // 0;
    $idx = ($idx + $direction) % @$keys;
    $idx += @$keys while $idx < 0;
    $state->{sort_idx} = $idx;
    $state->{process_sort} = $keys->[$idx];
}

sub process_sort_label ($state) {
    my %labels = (
        cpu     => 'CPU time',
        memory  => 'Memory',
        disk    => 'Disk I/O',
        network => 'Network I/O',
    );
    my $label = $labels{$state->{process_sort} // 'cpu'} // 'CPU';
    if (($state->{process_sort} // '') eq 'disk') {
        my $mode = ($state->{disk_order} // 'read') eq 'write' ? 'write' : 'read';
        return "$label ($mode)";
    }
    if (($state->{process_sort} // '') eq 'network') {
        my $mode = ($state->{net_order} // 'rx') eq 'tx' ? 'tx' : 'rx';
        return "$label ($mode)";
    }
    return $label;
}

sub sort_value ($row, $key, $state) {
    return 0 unless $row;
    return $row->{cpu_time}   // 0 if $key eq 'cpu';
    return $row->{memory}     // 0 if $key eq 'memory';
    if ($key eq 'disk') {
        return (($state->{disk_order} // 'read') eq 'write')
            ? ($row->{disk_write} // 0)
            : ($row->{disk_read} // 0);
    }
    if ($key eq 'network') {
        return (($state->{net_order} // 'rx') eq 'tx')
            ? ($row->{network_tx} // 0)
            : ($row->{network_rx} // 0);
    }
    return 0;
}

sub render_processes ($state, $renderer = undef) {
    my $rows_ref = $state->{process_rows};
    my $snap = $state->{snapshot};
    return 'waiting for sampler...' unless $rows_ref && @$rows_ref;
    my $sort_key = $state->{process_sort} // 'cpu';
    my @rows = sort {
        sort_value($b, $sort_key, $state) <=> sort_value($a, $sort_key, $state)
    } @$rows_ref;
    my $name_width = 16;
    my $available_rows = defined $renderer && $renderer->can('height')
        ? int($renderer->height // 0)
        : 0;
    my $header_rows = 2;
    my $limit = $available_rows > $header_rows ? $available_rows - $header_rows : 0;
    $limit = @rows if $limit > @rows;
    $limit = 0 if $limit < 0;
    my $text = sprintf "Top %s by %s | q=quit, Tab=cycle, K=reverse | sample #%s\n", $limit, process_sort_label($state), ($state->{process_tick} // 0);
    my $disk_label = ($state->{disk_order} // 'read') eq 'write' ? 'DiskW(KB)' : 'DiskR(KB)';
    $text .= sprintf "%-5s %-*s %10s %11s %11s\n", 'PID', $name_width, 'Name', 'CPU(s)', 'Memory', $disk_label;
    for my $idx (0 .. $limit - 1) {
        my $row = $rows[$idx];
        next unless $row;
        my $pid = sprintf '%5s', $row->{pid};
        my $name = sprintf "%-*.*s", $name_width, $name_width, ($row->{name} // 'unknown');
        my $cpu = sprintf '%9.2f', $row->{cpu_time} // 0;
        my $mem = sprintf '%10.1fM', ($row->{memory} // 0) / (1024 * 1024);
        my $disk_value = ($state->{disk_order} // 'read') eq 'write'
            ? ($row->{disk_write} // 0)
            : ($row->{disk_read} // 0);
        my $disk = sprintf '%10.1fK', ($disk_value // 0) / 1024;
        $text .= sprintf "%s %s %s %s %s\n", $pid, $name, $cpu, $mem, $disk;
    }
    return $text;
}

my $app = App {
    OnUpdate sub ($app, $dt, @events) {
        my $now = time;
        my $render_this_frame = @events ? 1 : 0;
        if ($now >= $state->{next_sample}) {
            my $snap = $sampler->snapshot;
            $state->{snapshot} = $snap if $snap;
            $state->{disk_space} = read_disk_space_snapshot();
            $state->{next_sample} = $now + $refresh_rate;
            my $delta_t = 0;
            if (defined $state->{_process_last_sample}) {
                $delta_t = $now - $state->{_process_last_sample};
            }
            $state->{_process_last_sample} = $now;
            $state->{process_rows} = read_process_snapshot_live($state, $delta_t);
            $state->{process_tick}++;
            $render_this_frame = 1;
        }
        $app->skip_render unless $render_this_frame;
    };
    OnKey 'q' => sub ($app, $event) {
        if ($state->{help_visible}) {
            $state->{help_visible} = 0;
            return;
        }
        $app->quit;
    };
    OnKey 'H' => sub ($app, $event) { toggle_help($state) };
    OnKey "\t" => sub ($app, $event) { cycle_sort($state, 1) };
    OnKey 'K' => sub ($app, $event) { cycle_sort($state, -1) };
    OnKey 'D' => sub ($app, $event) { toggle_disk_order($state) };
    OnKey 'N' => sub ($app, $event) { toggle_network_order($state) };
    OnKey 'j' => sub ($app, $event) {
        return unless $state->{help_visible};
        $state->{help_scroll}++;
    };
    OnKey 'k' => sub ($app, $event) {
        return unless $state->{help_visible};
        $state->{help_scroll}--;
    };

    Layer {
        VBox {
            BBox {
                VBox {
                    Text {} -text => 'CPU & MEMORY', -material => 'TITLE', -margin => 0;
                    Text {} -text => 'CPU Usage', -material => 'VALUE';

                        do {
                        my $bar_width_cb = bar_width_for_cpu_rows();
                        my $pair_count = cpu_display_pairs($state);
                        my $cpu_rows = cpu_core_count_from_snapshot($state);
                        for my $row_idx (0 .. $pair_count - 1) {
                            my $left = $row_idx * 2;
                            my $right = $left + 1;
                            if ($right < $cpu_rows) {
                                HBox {
                                    render_cpu_entry($state, $left, $bar_width_cb);
                                    Text {} -text => '  ';
                                    render_cpu_entry($state, $right, $bar_width_cb);
                                } -gap => 0, -margin => 0;
                            } else {
                                render_cpu_entry($state, $left, $bar_width_cb);
                            }
                        }
                        Text {} -text => sub {
                            my $pair_count = cpu_row_count_from_snapshot($state);
                            return '' if $pair_count > 0;
                            return $state->{snapshot} && $state->{snapshot}->{raw} ? 'No CPU data' : 'collecting CPU data...';
                        };
                    };

                    Text {} -text => sub { memory_summary_line($state) }, -material => 'TEXT', -margin => 0;
                    HBox {
                        build_gradient_bar(
                            sub { memory_percent($state) },
                            sub { bar_width_for_panel($_[0], 24) },
                        );
                    } -gap => 0, -margin => 0;
                } -gap => 0, -margin => 0, -overflow => 'clip';
            } -width => '100%', -height => sub { cpu_memory_panel_height($state, $_[1]) }, -material => 'PANEL', -border_material => 'FRAME', -margin => 0;
            HBox {
                BBox {
                    VBox {
                        Text {} -text => sub { disk_summary_title($state) }, -material => 'TITLE', -margin => 0;
                        HBox {
                        Text {} -text => 'Read ', -material => 'TEXT', -margin => 0;
                        build_gradient_bar(
                            sub { summarize_iostat_payload($state, 'disk', $state->{disk_order} // 'read')->{percent_read} // 0 },
                            sub { bar_width_for_half_panel($_[0], 18) },
                        );
                    } -gap => 0, -margin => 0;
                    HBox {
                        Text {} -text => 'Write', -material => 'TEXT', -margin => 0;
                        build_gradient_bar(
                            sub { summarize_iostat_payload($state, 'disk', $state->{disk_order} // 'read')->{percent_write} // 0 },
                            sub { bar_width_for_half_panel($_[0], 18) },
                        );
                    } -gap => 0, -margin => 0;
                        Text {} -text => sub { summarize_iostat($state, 'disk') }, -material => 'TEXT', -overflow => 'clip';
                    } -gap => 0, -margin => 0;
                } -width => '50%', -height => sub { panel_top_height() }, -material => 'PANEL', -border_material => 'FRAME', -margin => 0;
                BBox {
                    VBox {
                        Text {} -text => 'Disk Space', -material => 'TITLE', -margin => 0;
                        Text {} -text => sub { render_disk_space($state) }, -material => 'TEXT', -overflow => 'clip';
                    } -gap => 0, -margin => 0;
                } -width => '50%', -height => sub { panel_top_height() }, -material => 'PANEL', -border_material => 'FRAME', -margin => 0;
            } -gap => 1, -margin => 0;
            BBox {
                VBox {
                    Text {} -text => sub { network_summary_title($state) }, -material => 'TITLE', -margin => 0;
                    HBox {
                        Text {} -text => 'RX   ', -material => 'TEXT', -margin => 0;
                        build_gradient_bar(
                            sub { summarize_iostat_payload($state, 'network', $state->{net_order} // 'rx')->{percent_rx} // 0 },
                            sub { bar_width_for_panel($_[0], 34) },
                        );
                    } -gap => 0, -margin => 0;
                    HBox {
                        Text {} -text => 'TX   ', -material => 'TEXT', -margin => 0;
                        build_gradient_bar(
                            sub { summarize_iostat_payload($state, 'network', $state->{net_order} // 'rx')->{percent_tx} // 0 },
                            sub { bar_width_for_panel($_[0], 34) },
                        );
                    } -gap => 0, -margin => 0;
                    Text {} -text => sub { summarize_iostat($state, 'network') }, -material => 'TEXT', -overflow => 'clip';
                } -gap => 0, -margin => 0;
            } -width => '100%', -height => sub { panel_top_height() }, -material => 'PANEL', -border_material => 'FRAME', -margin => 0;
            BBox {
                Text {} -text => sub { render_processes($state, $_[1]) }, -material => 'TEXT', -overflow => 'clip';
            } -width => '100%', -height => sub { process_panel_height($state, $_[1]) }, -material => 'PANEL', -border_material => 'FRAME', -margin => 0;
            HBox {
                for my $part (help_bar_parts($state)) {
                    Text {} -text => $part->{text}, -material => $part->{material}, -margin => 0;
                }
            } -gap => 0, -margin => 0;
        } -gap => 0,
          -width => '100%',
          -height => '100%',
          -margin => 0,
          -x => sub ($app, $renderer, $node) { -int(($renderer->width // 0) / 2) },
          -y => sub ($app, $renderer, $node) { int(($renderer->height // 0) / 2) };
    };

    # Temporary: help modal disabled for debugging.
    # Layer {
    #     Rect {} -width => sub { $state->{help_visible} ? '100%' : 0 },
    #         -height => sub { $state->{help_visible} ? '100%' : 0 },
    #         -material => 'BACKDROP',
    #         -x => sub ($app, $renderer, $node) { -int(($renderer->width // 0) / 2) },
    #         -y => sub ($app, $renderer, $node) { int(($renderer->height // 0) / 2) };
    #     BBox {
    #         TextViewport {}
    #             -lines_ref => \@help_lines,
    #             -scroll_ref => \$state->{help_scroll},
    #             -width => '100%',
    #             -height => '100%',
    #             -margin => 0;
    #     } -width => sub { $state->{help_visible} ? '100%' : 0 },
    #       -height => sub { $state->{help_visible} ? '100%' : 0 },
    #       -material => 'PANEL',
    #       -border_material => 'FRAME',
    #       -margin => 0,
    #       -x => sub ($app, $renderer, $node) { -int(($renderer->width // 0) / 2) },
    #       -y => sub ($app, $renderer, $node) { int(($renderer->height // 0) / 2) };
    # };
};

$app->run($top_tool_theme);

__END__

=head1 NAME

top_tool.pl - Linux top-like TUI for CPU, memory, disk, network, and processes

=head1 SYNOPSIS

perl examples/linux/top_tool.pl [--refresh-rate SECONDS]

=head1 DESCRIPTION

This tool renders a split-screen terminal dashboard showing:

- CPU usage per core as horizontal bars (two-column layout)
- Memory usage as a bar and summary line
- Disk I/O split into read and write bars with per-device breakdown
- Network I/O split into RX and TX bars with per-interface breakdown
- A process list sorted by the selected metric

The UI updates at the configured refresh interval and supports key-driven
sorting and toggles.

=head1 LAYOUT SPECS

The UI tree is built from TML containers with this structure:

- Root: C<VBox>
- Row 1: C<BBox> (CPU & MEMORY)
  - Inner: C<VBox>
  - CPU list rendered as two-column rows (left/right CPU bars)
  - Memory summary + bar rendered below CPU rows
- Row 2: C<HBox> (two columns)
  - Left: C<BBox> (Disk I/O)
  - Right: C<BBox> (Disk Space)
- Row 3: C<BBox> (Network I/O)
- Row 4: C<BBox> (Processes)
- Row 5: Help bar as C<HBox> of labeled segments

=head2 Panel Order

Expected order (left-to-right, top-to-bottom):

1. CPU & Memory
2. Disk I/O
3. Disk Space
4. Network I/O
5. TOP processes

=head1 OPTIONS

=over 4

=item B<--refresh-rate> SECONDS

Refresh interval in seconds (default: 1).

=item B<-h>, B<--help>

Show this help text.

=back

=head1 KEYBINDINGS

=over 4

=item B<q>

Quit the application.

=item B<Tab>

Cycle process sort key (CPU, memory, disk, network).

=item B<K>

Reverse the sort direction.

=item B<D>

Toggle disk ordering between read and write.

=item B<N>

Toggle network ordering between RX and TX.

=back

=head1 SIGNALS

=over 4

=item B<SIGUSR1>

Restart the process by execing itself with the original arguments.

=back

=head1 EXAMPLES

Run with a 2-second refresh interval:

  perl examples/linux/top_tool.pl --refresh-rate 2

Reset a running instance by PID:

  kill -USR1 <pid>

=head1 NOTES

This tool requires a real TTY; stdin must be a terminal device.

=cut
