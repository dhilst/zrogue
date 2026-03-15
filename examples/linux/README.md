# Linux Top Tool

This runnable TUI shows real-time Linux `/proc` metrics: CPU percentages, memory usage, disk and network throughput, plus a sortable process list. It is built with the existing `MetricSampler` data module and the TML-driven renderer used throughout the repo.

## Running

```sh
perl examples/linux/top_tool.pl
```

The tool samples `/proc/stat`, `/proc/meminfo`, `/proc/diskstats`, `/proc/net/dev`, and `/proc/[pid]/{stat,io}` on each frame (default ~60 FPS). The output includes:

- Horizontal bars per CPU core with usage (%) labels.
- Memory usage bar summarizing total/used/available RAM.
- Disk and network bars showing KB/s throughput (per-second deltas).
- Process table sorted by the active metric (CPU, memory, disk, or network).

## Controls

- `Tab` cycles forward through `CPU`, `Memory`, `Disk`, and `Network` sort orders.
- `K` cycles backward.
- `q` exits the tool cleanly.

The current sort mode is shown above the process table.
