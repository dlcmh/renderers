# Metal Launch Window (Rust / Metal)

Task: [0001 — Empty launch window](../README.md). Rust CPU baseline:
[rust-appkit](../rust-appkit/). Swift Metal counterpart:
[swift-metal](../swift-metal/). Repository rules: [AGENTS.md](../../AGENTS.md).

This variant opens a native macOS window and clears its `CAMetalLayer` to dark
blue using Metal, entirely from Rust. The Metal objects and the frame sequence are
the same as the Swift variant; only the host language and ownership model differ.

## Run

From the repository root, with build artifacts under `/tmp/renderers`:

```sh
./scripts/run.sh rust-metal
```

Or invoke Cargo directly:

```sh
cd 0001-empty-launch-window
CARGO_TARGET_DIR=/tmp/renderers/rust-target cargo run -p rust-metal
```

A centered, resizable 1280×720 window opens with a dark blue surface. Close the
window, press Escape, or press ⌘Q to quit.

## Comparison

| | Swift / Metal | Rust / Metal | Rust / AppKit |
| --- | --- | --- | --- |
| Window host | AppKit | AppKit | AppKit |
| Surface | `CAMetalLayer` | `CAMetalLayer` | AppKit backing store |
| GPU API | Metal | Metal | None |
| Frame loop | event-driven | event-driven | AppKit draw |
| GPU object ownership | ARC | `Retained<ProtocolObject<…>>` | n/a |
| Host-side safety | Swift | `unsafe` FFI with SAFETY comments | `unsafe` FFI with SAFETY comments |
| Content | dark blue clear | dark blue clear | black fill |

The GPU commands are identical. Language choice does not change the clear cost or
the presentation path; it changes how objects are owned and how much of the code
is inside `unsafe`.

## How it works

1. **Create the device and queue** at [src/main.rs:96](src/main.rs#L96) and
   [src/main.rs:100](src/main.rs#L100). `MTLCreateSystemDefaultDevice()` needs
   CoreGraphics linked, hence the empty `#[link]` block near the top of
   [src/main.rs](src/main.rs#L21).
2. **Install the application menu** at [src/main.rs:26](src/main.rs#L26). A
   programmatic app has no menu bar, so this adds the standard Quit item and makes
   ⌘Q work.
3. **Create the window and install a `MetalView`** at
   [src/main.rs:80](src/main.rs#L80). The view is a layer-hosting `NSView`.
4. **Configure the `CAMetalLayer`** in
   [src/metal_view.rs:84](src/metal_view.rs#L84): BGRA8 drawable format, opaque,
   framebuffer-only, and a three-drawable pool.
5. **Attach the layer to the view** at
   [src/metal_view.rs:101](src/metal_view.rs#L101).
6. **Keep the drawable in pixels** in
   [src/metal_view.rs:108](src/metal_view.rs#L108). AppKit reports points; a 2×
   Retina display needs a 2× drawable.
7. **Encode one clear pass** in
   [src/metal_view.rs:123](src/metal_view.rs#L123). Acquire a drawable, create a
   command buffer, set the color attachment's clear color, end encoding, present,
   and commit.
8. **Render on layout events.** `setFrameSize:`, `viewDidMoveToWindow`, and
   `viewDidChangeBackingProperties` update the drawable size and submit a frame
   (see [src/metal_view.rs:35](src/metal_view.rs#L35)). There is no display link,
   so this is not a continuous game loop yet.

No shader or pipeline is needed: clearing is a fixed-function render-pass step.
That boundary is deliberate; the next renderer concept is a pipeline and a draw
call.

## Ownership across the Metal boundary

- The `CAMetalLayer` is stored in `MetalViewIvars` as `Retained<CAMetalLayer>`.
  AppKit also retains the view, and the view's layer retains the device.
- The `MTLCommandQueue` is stored as
  `Retained<ProtocolObject<dyn MTLCommandQueue>>`. It is long-lived and reused for
  every frame.
- A command buffer and drawable are scoped to one `render()` call. The drawable is
  borrowed from the layer's pool, presented, and returned when the command buffer
  completes.
- The command buffer retains the objects it references by default, so no manual
  lifetime extension is needed for this single-frame example.

The `unsafe` blocks implement two narrow operations: calling the superclass
implementation of overridden AppKit methods, and indexing color attachment zero,
which Metal guarantees exists. Both carry SAFETY comments.

## Performance

This variant performs the same Metal commands as the Swift version, so there is no
meaningful GPU-side difference. Host overhead is a few Objective-C message sends
per layout event, not a per-pixel cost. For a static clear, Metal is still not
automatically faster than AppKit; the GPU path becomes valuable as per-pixel work
and draw-call complexity grow. See the
[Swift Metal performance section](../swift-metal/README.md#is-it-faster) and
[Graphics concepts and portability](../../docs/GRAPHICS-CONCEPTS.md) for the
broader comparison.

## Deliberate omissions

- No shader, pipeline, vertex buffer, or draw call.
- No continuous frame loop, display link, or in-flight frame semaphore.
- No menu commands beyond the standard Quit item (⌘Q).
- No input handling beyond Escape, or cross-platform surface abstraction.

## Verification

- `cargo build -p rust-metal` and
  `cargo clippy -p rust-metal --all-targets -- -D warnings` pass.
- Launched from the task workspace; the macOS window server reported an on-screen
  window owned by `rust-metal` at layer 0 with a 1280×752 outer frame.
- Screen capture was unavailable because Screen Recording permission was not
  granted; the dark blue pixels were verified by code path and window presence.

## Structure

- `src/main.rs` — device/queue creation, window creation, app lifecycle.
- `src/metal_view.rs` — layer-backed view, drawable resize, render pass.
- `src/app_delegate.rs` — quit-after-last-window-closed behavior.
- `Cargo.toml` — Metal, AppKit, Foundation, and QuartzCore bindings.
- The shared task workspace and tooling live one level up.
