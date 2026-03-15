package MetricSampler;

use v5.36;
use strict;
use warnings;
use Carp qw(confess);
use Time::HiRes qw(time);
use POSIX qw(sysconf _SC_CLK_TCK _SC_PAGESIZE);
use List::Util qw(sum);
use File::Spec;

my $CLK_TCK   = sysconf(_SC_CLK_TCK) // confess 'failed to read _SC_CLK_TCK';
my $PAGE_SIZE = sysconf(_SC_PAGESIZE) // 4096;

sub new ($class, %args) {
    my $self = {
        proc_root => $args{proc_root} // '/proc',
        prev      => undef,
    };
    return bless $self, __PACKAGE__;
}

sub snapshot ($self) {
    my $now = time;
    my $raw = {
        cpu     => $self->_read_cpu,
        memory  => $self->_read_memory,
        disk    => $self->_read_disk,
        network => $self->_read_network,
        process => $self->_read_process,
    };

    my $result = {
        timestamp => $now,
        raw       => $raw,
    };

    $result->{memory} = $self->_build_memory_snapshot($raw->{memory});

    if ($self->{prev}) {
        my $delta_t = $now - $self->{prev}->{timestamp};
        $result->{delta_t} = $delta_t;
        $result->{cpu} = $self->_cpu_snapshot($raw->{cpu}, $self->{prev}->{raw}->{cpu});
        $result->{disk} = $self->_io_snapshot($raw->{disk}, $self->{prev}->{raw}->{disk}, $delta_t);
        $result->{network} = $self->_io_snapshot($raw->{network}, $self->{prev}->{raw}->{network}, $delta_t);
        $result->{process} = $self->_process_snapshot($raw->{process}, $self->{prev}->{raw}->{process}, $delta_t);
    }

    $self->{prev} = $result;
    return $result;
}

sub _read_cpu ($self) {
    my $path = File::Spec->catfile($self->{proc_root}, 'stat');
    open my $fh, '<', $path or confess "stat: $!";
    my %cores;
    while (my $line = <$fh>) {
        next unless $line =~ /^(cpu\d*)\s+(.*)$/;
        my ($id, $numbers) = ($1, $2);
        my @values = split ' ', $numbers;
        my $total = 0 + sum(@values);
        my $idle = $values[3] // 0;
        $cores{$id} = { total => $total, idle => $idle };
    }
    close $fh;
    return { cores => \%cores };
}

sub _read_memory ($self) {
    my $path = File::Spec->catfile($self->{proc_root}, 'meminfo');
    open my $fh, '<', $path or confess "meminfo: $!";
    my (%mem, $total);
    while (my $line = <$fh>) {
        if ($line =~ /^(\w+):\s+(\d+)/) {
            $mem{$1} = $2;
        }
    }
    close $fh;
    return {
        total     => $mem{MemTotal} // 0,
        available => $mem{MemAvailable} // ($mem{MemFree} // 0),
    };
}

sub _build_memory_snapshot ($self, $memory_raw) {
    my $total = $memory_raw->{total} // 0;
    my $available = $memory_raw->{available} // 0;
    my $used = $total - $available;
    $used = 0 if $used < 0;
    return {
        total     => $total,
        available => $available,
        used      => $used,
        percent   => $total ? ($used / $total) * 100 : 0,
    };
}

sub _read_disk ($self) {
    my $path = File::Spec->catfile($self->{proc_root}, 'diskstats');
    open my $fh, '<', $path or confess "diskstats: $!";
    my %stats;
    while (my $line = <$fh>) {
        my @fields = split ' ', $line;
        next unless @fields >= 14;
        my ($major, $minor, $name) = @fields[0,1,2];
        next if $name =~ /loop|ram/;
        my $reads = $fields[3] // 0;
        my $rd_sectors = $fields[5] // 0;
        my $writes = $fields[7] // 0;
        my $wr_sectors = $fields[9] // 0;
        $stats{$name} = {
            read_ops   => $reads,
            read_bytes => $rd_sectors * 512,
            write_ops  => $writes,
            write_bytes => $wr_sectors * 512,
        };
    }
    close $fh;
    return \%stats;
}

sub _read_network ($self) {
    my $path = File::Spec->catfile($self->{proc_root}, 'net', 'dev');
    open my $fh, '<', $path or confess "net/dev: $!";
    my %interfaces;
    <$fh>; <$fh>;
    while (my $line = <$fh>) {
        next unless $line =~ /^\s*([^:]+):\s*(.*)$/;
        my ($iface, $data) = ($1, $2);
        my @fields = split ' ', $data;
        my $rx = $fields[0] // 0;
        my $tx = $fields[8] // 0;
        $interfaces{$iface} = { rx_bytes => $rx, tx_bytes => $tx };
    }
    close $fh;
    return \%interfaces;
}

sub _read_process ($self) {
    my $proc = $self->{proc_root};
    opendir my $dir, $proc or confess "proc: $!";
    my @pids = grep {/^\d+$/} readdir $dir;
    closedir $dir;
    my @list;
    foreach my $pid (@pids) {
        my $stat_path = File::Spec->catfile($proc, $pid, 'stat');
        next unless -r $stat_path;
        open my $fh, '<', $stat_path or next;
        my $line = <$fh>;
        close $fh;
        next unless $line;
        my @fields = split ' ', $line;
        my $comm = $fields[1];
        $comm =~ s/^\(//;
        $comm =~ s/\)$//;
        my $utime = $fields[13] // 0;
        my $stime = $fields[14] // 0;
        my $rss   = $fields[23] // 0;
        my $io    = $self->_read_process_io($pid);
        push @list, {
            pid   => $pid + 0,
            name  => $comm,
            utime => $utime,
            stime => $stime,
            rss   => $rss,
            io    => $io,
        };
        last if @list >= 64;
    }
    return \@list;
}

sub _read_process_io ($self, $pid) {
    my $path = File::Spec->catfile($self->{proc_root}, $pid, 'io');
    return {} unless -r $path;
    open my $fh, '<', $path or return {};
    my %values;
    while (my $line = <$fh>) {
        if ($line =~ /^(\w+):\s+(\d+)/) {
            $values{$1} = $2;
        }
    }
    close $fh;
    return \%values;
}

sub _cpu_snapshot ($self, $curr, $prev) {
    my @rows;
    while (my ($id, $values) = each %{ $curr->{cores} }) {
        my $prev_values = $prev ? $prev->{cores}{$id} : undef;
        my $usage = 0;
        if ($prev_values) {
            my $delta_total = $values->{total} - $prev_values->{total};
            my $delta_idle = $values->{idle} - $prev_values->{idle};
            $usage = $delta_total > 0 ? (($delta_total - $delta_idle) / $delta_total) * 100 : 0;
        }
        push @rows, { id => $id, usage => $usage };
    }
    @rows = sort { $a->{id} cmp $b->{id} } @rows;
    return \@rows;
}

sub _io_snapshot ($self, $curr, $prev, $delta_t) {
    return {} unless $prev && $delta_t > 0;
    my %summary;
    while (my ($key, $value) = each %$curr) {
        my $prev_value = $prev->{$key} // {};
        if (ref $value eq 'HASH') {
            my %entry;
            while (my ($metric, $v) = each %$value) {
                my $pv = $prev_value->{$metric} // 0;
                $entry{$metric} = ($v - $pv) / $delta_t;
            }
            $summary{$key} = \%entry;
        }
    }
    return \%summary;
}

sub _process_snapshot ($self, $curr, $prev, $delta_t) {
    return [] unless $prev && $delta_t > 0;
    my %prev_by_pid = map { $_->{pid} => $_ } @$prev;
    my @rows;
    foreach my $proc (@$curr) {
        my $previous = $prev_by_pid{$proc->{pid}};
        my $total_time = ($proc->{utime} + $proc->{stime}) - (($previous->{utime} // 0) + ($previous->{stime} // 0));
        my $cpu_time = $total_time / $CLK_TCK;
        my $memory = ($proc->{rss} // 0) * $PAGE_SIZE;
        my $curr_io_bytes = ($proc->{io}{read_bytes} // 0) + ($proc->{io}{write_bytes} // 0);
        my $prev_io_bytes = 0;
        if ($previous && $previous->{io}) {
            $prev_io_bytes = ($previous->{io}{read_bytes} // 0) + ($previous->{io}{write_bytes} // 0);
        }
        my $delta_io = $curr_io_bytes - $prev_io_bytes;
        my $disk_io = $delta_t > 0 ? ($delta_io / $delta_t) : 0;
        push @rows, {
            pid        => $proc->{pid},
            name       => $proc->{name},
            cpu_time   => $cpu_time,
            memory     => $memory,
            disk_io    => $disk_io > 0 ? $disk_io : 0,
            network_io => 0,
        };
    }
    @rows = sort { $b->{cpu_time} <=> $a->{cpu_time} } @rows;
    return \@rows;
}

1;
