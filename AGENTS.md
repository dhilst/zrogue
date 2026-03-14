# AGENTS.md

## Code guidelines

- Use Perl `v5.36` in this codebase.
- Do not use exceptions.
- Avoid `eval { }` blocks.
- Use `confess` to raise unrecoverable errors.
- Do not use naive setters like `$obj->set_velocity($new_v)`; use semantic method names that describe the state transition, like `$obj->accelerate($force_vec)`.
- Return objects with `bless $self, __PACKAGE__` semantics rather than blessing into a caller-supplied class.
- Inheritance is forbidden in this repository. Treat each package as a concrete type, not a base class.
- Because inheritance is forbidden, instantiate objects as `MyClass::new(@params)`, not `MyClass->new(@params)`.
- Add POD documentation after `__END__` and use `pod2usage` for CLI contracts.
- Use `TerminalStyle` for reusable terminal styling objects instead of passing loose style hashrefs around new code.

## Mental model

`zrogue` is a Perl terminal UI/game sandbox centered on a single render loop and a declarative UI tree.

Runtime flow:

1. `zrogue.pl` builds a `TML` app tree with `App { ... }`.
2. That app object is passed to `GameLoop::new(...)` as the widget to drive.
3. `GameLoop` owns terminal sizing, raw keyboard input, frame timing, and renderer lifecycle.
4. Each tick calls `app->update($dt, @events)` and then `app->render($renderer)` unless the app requested `skip_render`.
5. Rendering goes through `Renderers::DoubleBuffering`, which diffs packed buffers and flushes only changed cells to the terminal.

This means most feature work lands in one of three places:

- `zrogue.pl` for the current demo screen and app-local behavior.
- `TML.pm` for declarative layout/render semantics.
- Lower-level modules such as `Renderers.pm`, `Buffer2D.pm`, `Surface.pm`, `Input.pm`, and `Termlib.pm` for engine behavior.

## Core modules

- `zrogue.pl`: current entry point and demo application. It builds a static RPG-style HUD with dynamic FPS text and a `q` quit handler.
- `GameLoop.pm`: event loop based on `AnyEvent` + `EV`. Responsible for resize handling, draining input events, rebuilding the renderer, calling `update`, and flushing renders.
- `TML.pm`: the main EDSL/runtime. `App`, `Layer`, `VBox`, `HBox`, `BBox`, `Rect`, and `Text` create a tree of plain Perl hashes; `TML::Runtime::App` implements update/render behavior, event hooks, layout calculation, and layout caching.
- `Renderers.pm`: contains `Renderers::Naive` and `Renderers::DoubleBuffering`. The double-buffered renderer is the important one in normal runtime.
- `Buffer2D.pm`: packed 2D storage used by the renderer and surfaces. Tests show this is a critical invariant-heavy module.
- `Surface.pm`: off-screen drawing abstraction used heavily by tests and some rendering helpers.
- `Input.pm`: switches stdin into raw mode, decodes UTF-8 with `UTF8Buffer`, and emits key press events.
- `Termlib.pm`: low-level terminal cursor movement, clearing, and ANSI color output.
- `Matrix3.pm`, `Quad.pm`, `Viewport.pm`, `Geometry3.pm`: geometry and coordinate utilities used throughout rendering/layout code.
- `MaterialMapper.pm` and `BorderMapper.pm`: style lookup helpers for colors/attrs and border glyph sets.

## Coordinate and layout conventions

- The code uses a Cartesian-style internal coordinate system where positive `x` goes right and more negative `y` moves downward on screen.
- `GameLoop::terminal_space()` maps world/UI coordinates into terminal coordinates by translating to the screen center and reflecting the Y axis.
- In `TML`, child node `-x` and `-y` are local offsets from the parent origin. Container layout code computes placements, then `_render_node` converts those into actual child origins.
- `BBox` reserves a one-cell border on each side; its children render into the inner content region.
- Width/height options can be integers, numeric strings, percentage strings like `'50%'`, or coderefs. Coderefs are treated as dynamic and affect layout caching.

## State and events

- `TML::Runtime::App->state` is the mutable app state bag for demo/application logic.
- `OnUpdate` callbacks run every tick before key handlers.
- `OnKey` handlers are simple exact-character matches against decoded key press events.
- `quit()` stops the loop by making `update()` return `0`.
- `skip_render()` makes the next `update()` return `-1`, which `GameLoop` interprets as “update happened, but do not render this widget this frame”.

## Performance-sensitive areas

- `Renderers::DoubleBuffering` and `Buffer2D` are the main hot path. Preserve packed-buffer assumptions unless you are intentionally changing the renderer contract.
- `TML.pm` has persistent and per-frame layout caches keyed by tree shape, node identity, renderer size, and whether props are dynamic. If layout behavior seems stale, inspect `_refresh_layout_caches`, `_tree_signature_walk`, and the `_cache_*` helpers first.
- The `nytprof*` directories and `nytprof*.out` files are profiling artifacts, not source modules. Ignore them unless the task is specifically about profiling.

## Tests

- Tests live in `t/*.t` and cover the engine modules much better than the demo entry point.
- `t/TML_test.t`, `t/GameLoop_test.t`, `t/Renderers_test.t`, and `t/Surface_test.t` are the best starting points when changing runtime behavior.
- Run `prove -l` from the repo root for the normal test pass.

## Practical guidance for future agents

- Treat `zrogue.pl` as a demo/composition layer, not the engine definition.
- When changing layout behavior, verify both rendering and cache invalidation behavior; `TML_test.t` already exercises several cache edge cases.
- Be careful with terminal assumptions: `Input.pm` requires a TTY, and `Termlib.pm` shells out to `tput` for dimensions.
- Preserve UTF-8 handling. Input decoding goes through `UTF8Buffer`, and the source files use `use utf8;` in several key modules.

## Building runnable TUIs in this repository

This section is the operational guide for building production-quality runnable
examples and terminal apps on top of `TML`.

### Primary objective

A runnable TUI in this repo should satisfy all of these:

1. start in a real TTY and render correctly at the current terminal size
2. accept local and cross-container navigation using the repository keymap model
3. execute app lifecycle callbacks (`-setup`, `-action`, `-exit`) predictably
4. restore terminal mode/cursor state on every exit path
5. produce deterministic output suitable for automated verification

### Layer map for runnable TUIs

Use this explicit layering when you design a new runnable:

1. Composition layer (`examples/runnable/*.pl`)
   define state, build the `App { ... }` tree, wire callbacks, provide result reporting
2. Interaction/layout layer (`TML.pm`)
   focus model, local-vs-exit navigation, layout resolution, rendering semantics
3. Runtime layer (`GameLoop.pm`, `Input.pm`)
   raw input, update/render ticking, resize handling, event draining
4. Render backend (`Renderers.pm`, `Buffer2D.pm`, `Termlib.pm`)
   drawing, diffing, terminal flushing

Contract boundary rule:
- composition code may describe desired behavior but must not reimplement focus,
  input decoding, frame scheduling, or terminal flushing.

### Lifecycle contract for runnable apps

When using `App`, follow this contract:

- `-setup` (optional):
  pre-condition: renderer/runtime info is available
  statement: initialize app state derived from runtime (for example `cols x rows`)
  post-condition: state is ready before first interactive frame
- `-action` (optional):
  pre-condition: user triggered run path and app is in interactive state
  statement: perform work, emit progress via `$report->({...})`, return result payload
  post-condition: `action_phase`, captured stdout/stderr, result, and action exit code
  are available to `-exit`
- `-exit` (optional):
  pre-condition: app is finishing after action completion or quit path
  statement: print/record final report and map lifecycle outcome to process exit code
  post-condition: terminal is restored and process exits deterministically

Important:
- process exit code and `action_exit_code` are distinct concepts. `-exit` can map
  an action success/failure payload to a different process status by policy.

### Recommended file pattern for `examples/runnable`

Use this structure for new runnable examples:

1. imports + `use v5.36; use utf8;`
2. `use RunnableSupport qw(theme frame_update sleep_step ...);`
3. state and data declarations (`%state`, lists/options/log lines)
4. `my $ui = App { ... } -state => ..., -setup => ..., -action => ..., -exit => ...;`
5. `$ui->run(theme());`
6. POD after `__END__`

Keep app state in `$app->state`/bound refs and keep behavior semantic:
- prefer methods/callbacks with intent (`start_action`, `quit`, report progress)
- avoid ad hoc global mutation outside clearly owned app state

### Input and navigation model

Default keymap semantics in focus-aware trees:

- local navigation: `j`/`k`
- exit navigation: `J`/`K`

Focus behavior conventions:

- `List`, `FieldList`, and `TextViewport` own local navigation when movement is
  possible inside their domain
- when a local domain cannot move further, navigation may fall through to
  container-level traversal (critical for mixed-pane dialogs)
- `FocusScope`/`InputRoot` define navigation domains; use them intentionally
  around multi-pane/multi-branch layouts
- `ButtonRow` is a container with local branch traversal; prefer it for grouped
  action controls

### Rendering and update loop guidance

- use `OnUpdate { frame_update(@_) }` in runnable examples unless there is a
  strong reason to diverge
- call `$app->skip_render` only to avoid redundant frames; never use it to mask
  state bugs
- keep expensive computations out of per-frame callbacks when possible
- ensure all dynamic width/height/text coderefs are deterministic for tests

### Minimal runnable template

```perl
use v5.36;
use utf8;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib $Bin;

use RunnableSupport qw(theme frame_update sleep_step format_exit_report);
use TML qw(App Layer InputRoot VBox BBox Rect Text Button OnKey OnUpdate);

my %state = (label => 'demo');

my $ui = App {
    OnUpdate { frame_update(@_) };
    OnKey 'q' => sub ($app, $event) { $app->quit };

    Layer {
        Rect {} -width => '100%', -height => '100%', -material => 'BACKDROP';
        BBox {
            VBox {
                Text {} -text => 'Runnable Template', -material => 'TITLE';
                InputRoot {
                    Button {} -label => 'Run', -focused_material => 'FOCUS',
                        -on_press => sub ($app, $node) { $app->start_action('demo') }, -margin => 0;
                } -margin => 0;
            } -gap => 1;
        } -width => 44, -height => 10, -material => 'PANEL', -border_material => 'FRAME';
    } -x => -20, -y => 4;
} -state => \%state,
  -action => sub ($app, $report, $label) {
      $report->({ message => "running $label" });
      sleep_step(0.10);
      return { label => $label };
  },
  -exit => sub ($app, $result) {
      print format_exit_report('template', $result);
      exit(($result->{action_exit_code} // 1) == 0 ? 0 : 1);
  };

$ui->run(theme());
```

### Verification workflow for runnable TUIs

Use the same strategy as the runnable batch verifier:

1. drive each app through a real PTY (`script -qefc`) so raw mode behavior is real
2. feed deterministic key sequences
3. strip carriage returns from transcripts
4. assert:
   - process exit code
   - `phase=...`
   - `exit_code=...` (action exit code)
   - `result.*`
   - captured `stdout=` / `stderr=`

If behavior diverges:
- inspect transcript last rendered state first
- then classify as one of:
  - wrong scripted sequence
  - stale expected-output assertion
  - runtime/navigation bug requiring code change

### Debugging checklist for new runnable screens

- no input events:
  confirm execution is under a TTY; `Input.pm` will `confess` if `STDIN` is not a TTY
- focus appears stuck:
  inspect `InputRoot`/`FocusScope` boundaries and container branching
- `J`/`K` does not move panes:
  verify the currently focused widget can yield to exit navigation in that state
- stale layout after prop changes:
  inspect `TML` layout cache invalidation paths
- terminal left in bad state:
  verify exits route through lifecycle completion and avoid abrupt process kills

### Style/material conventions for runnable demos

- use shared theme/material keys (`TITLE`, `MUTED`, `VALUE`, `FOCUS`, etc.) rather
  than ad hoc hardcoded style structures
- use `TerminalStyle` and related style helpers for reusable styling behavior
- keep borders/panels consistent with existing runnable examples unless the task
  is explicitly about new visual language

## Abstraction decomposition and implementation

All non-trivial coding work should be decomposed into abstractions with well
defined boundaries and APIs.

### Required decomposition process

Before implementation begins:

1. Identify the top-level abstraction needed to solve the user-visible problem.
2. Analyze the current codebase abstractions to determine whether they can or
   should be reused, extended, or generalized within the current abstraction
   layer before introducing new ones.
3. Decompose the top-level abstraction into lower-level abstractions in a way
   that induces a well-defined layered structure.
4. Ensure each layer uses lower-level abstractions to achieve its goal.
5. Ensure each layer defines its own problem domain.
6. Ensure there is no domain contamination between layers: upper layers should
   not need to know lower-layer domain details, and lower layers should not
   need to know upper-layer domain details.
7. Continue decomposition until each abstraction has a focused
   responsibility and a defensible boundary.
8. Define the layer ordering explicitly so it is clear which abstractions are
   foundational and which depend on them.
9. Define the contract between each abstraction and the layer directly above or
   below it before writing code.

Do not start implementation until the abstractions, their layers, and their
contracts are clear enough to guide the work.

### Contract requirements

Each abstraction contract should be written so it supports Hoare-triple style
reasoning:

- pre-conditions
- statements
- post-conditions

Interpret them as follows:

- Pre-conditions: what must already be true before the abstraction is entered.
- Statements: the behavior the abstraction performs when invoked.
- Post-conditions: what must be true after the abstraction completes, assuming
  the pre-conditions held.

The intended semantics are:

- execution must fail before any statement is evaluated if the pre-conditions
  are not met
- the statements should succeed if the pre-conditions are met
- the post-conditions must hold after statement evaluation if the
  pre-conditions were met

In this repository, unrecoverable contract violations should usually fail via
`confess`, not exceptions or `eval`.

### Enforcement rules

Contracts should be enforced with tests and assertions.

Use:

- assertions and validation at abstraction boundaries
- focused tests for pre-condition rejection
- focused tests for post-condition guarantees
- integration tests for cross-layer behavior

Exception:

- in hot paths, pre-conditions may be assumed once the surrounding layer has
  already validated them
- if a hot path omits repeated checks, that assumption must still be defended by
  tests or assertions at a colder boundary

### Implementation order

Implementation order is bottom-up.

That means:

1. implement the lowest-level abstractions first
2. test and validate them in isolation
3. implement the abstractions that depend on them only after the lower layer is
   stable
4. repeat until the top-level abstraction is complete

Upper layers should not force ad hoc behavior into lower layers.

If an upper-layer abstraction reveals that a lower-layer abstraction is too
specific, then the lower-layer contract must be generalized first. That
generalization must preserve the lower layer's useful guarantees without losing
generality or turning it into a vague catch-all API.

### Multi-phase implementation workflow

During multi-phase work, agents should explicitly track these phases:

1. Problem framing
   Define the user-visible goal and the top-level abstraction.
2. Abstraction map
   List the abstractions, their responsibilities, and their layer order.
3. Contract definition
   For each abstraction, define pre-conditions, statements, and
   post-conditions.
4. Bottom-layer implementation
   Implement and test the foundational abstractions first.
5. Layer integration
   Build the next abstraction on top only after the lower layer contract is
   validated.
6. Generalization pass
   If a higher layer needs more from a lower layer, revise the lower layer
   contract deliberately before continuing.
7. Full-system validation
   Verify that the composed abstractions satisfy the original problem.
8. Strength analysis
   Review all abstraction models and contracts to ensure they are not too weak
   to be useful or too strong to be reusable.

### Practical checklist for agents

Before coding:

- name the abstractions
- identify their boundaries
- define their layer order
- define the contract for each boundary

While coding:

- implement from lower layers upward
- validate each abstraction before building on it
- keep APIs semantic and minimal
- reject invalid inputs at the boundary unless the code is in a justified hot
  path

When requirements change:

- do not patch around a broken lower-layer contract from the upper layer
- generalize the lower-layer abstraction first
- update tests and assertions to match the generalized contract

After implementation:

- verify the top-level behavior end to end
- review whether any abstraction contract is too weak, too strong, or leaking
  responsibilities across layers
