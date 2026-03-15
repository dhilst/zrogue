# ztui

`ZTUI` is a Perl terminal UI and rendering toolkit with a declarative `TML`
runtime, packed-buffer rendering, and geometry helpers.

**What’s here**

- Renderers for direct and double-buffered drawing
- Packed 2D buffers for fast updates
- Geometry parsing with labeled anchor points
- A `TML` demo UI in `examples/zrogue.pl`

**Run**

Run from source checkout:

```bash
perl examples/zrogue.pl
```

CPAN-style install workflow:

```bash
perl Makefile.PL
make
make test
make install
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

- `lib/ZTUI/Renderers.pm` contains `Renderers::Naive` and `Renderers::DoubleBuffering`
- `lib/ZTUI/Buffer2D.pm` stores packed per-cell data
- `lib/ZTUI/Surface.pm` composes layers into a buffer
- `lib/ZTUI/UTF8Buffer.pm` decodes UTF-8 byte streams
- `lib/ZTUI/TML.pm` contains the declarative tree/runtime
- `examples/zrogue.pl` wires the demo UI together

If you want a different control scheme or widget behavior, say the word.
