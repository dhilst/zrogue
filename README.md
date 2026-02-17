# zrogue

Terminal UI experiments in Perl. The project includes a small rendering stack
with double buffering, geometry helpers, and a few input widgets.

**What’s here**

- Renderers for direct and double-buffered drawing
- Packed 2D buffers for fast updates
- Geometry parsing with labeled anchor points
- Menu/Question demo widgets in `zrogue.pl`
- Input widgets: text, checkbox, select

**Run**

```bash
perl zrogue.pl
```

**Tests**

```bash
prove -l
```

**Input controls (current demo)**

- `j/k` move menu focus
- `h/j/k/l` move the menu widget
- `Enter` activates the focused input
- `Esc` exits active input mode

**Unicode input**

Input is read in raw mode and decoded via `UTF8Buffer`. Your terminal must be
configured for UTF‑8 for characters like `é` to work correctly.

**Project layout**

- `Renderers.pm` contains `Renderers::Naive` and `Renderers::DoubleBuffering`
- `Buffer2D.pm` stores packed per-cell data
- `Surface.pm` composes layers into a buffer
- `UTF8Buffer.pm` decodes UTF‑8 byte streams
- `TextInput.pm`, `CheckboxInput.pm`, `SelectInput.pm` are input widgets
- `zrogue.pl` wires the demo UI together

If you want a different control scheme or widget behavior, say the word.
