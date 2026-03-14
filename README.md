# zrogue

Terminal UI experiments in Perl. The project includes a small rendering stack
with double buffering, geometry helpers, and a declarative `TML` runtime.

**What’s here**

- Renderers for direct and double-buffered drawing
- Packed 2D buffers for fast updates
- Geometry parsing with labeled anchor points
- A `TML` demo UI in `zrogue.pl`

**Run**

```bash
perl zrogue.pl
```

**Tests**

```bash
prove -l
```

**Input controls (current demo)**

- `q` quits the demo

**Unicode input**

Input is read in raw mode and decoded via `UTF8Buffer`. Your terminal must be
configured for UTF‑8 for characters like `é` to work correctly.

**Project layout**

- `Renderers.pm` contains `Renderers::Naive` and `Renderers::DoubleBuffering`
- `Buffer2D.pm` stores packed per-cell data
- `Surface.pm` composes layers into a buffer
- `UTF8Buffer.pm` decodes UTF‑8 byte streams
- `TML.pm` contains the declarative tree/runtime
- `zrogue.pl` wires the demo UI together

If you want a different control scheme or widget behavior, say the word.
