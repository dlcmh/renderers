# First Triangle (Rust / Metal)

Task: [0002 — First triangle](../README.md). C++ counterpart:
[cpp-metal](../cpp-metal/). Shared shader:
[triangle.metal](../shaders/triangle.metal). Repository rules:
[AGENTS.md](../../AGENTS.md).

An RGB triangle drawn every display refresh, from Rust, directly against Metal.

## Run

From the repository root, with build artifacts under `/tmp/renderers`:

```sh
./scripts/run.sh rust-metal-triangle
```

Or with Cargo directly:

```sh
cd 0002-first-triangle
CARGO_TARGET_DIR=/tmp/renderers/0002-rust-target cargo run
```

A triangle with red, green, and blue vertices appears on the dark blue clear. Close
the window, press Escape, or press ⌘Q to quit.

## The delta from 0001

| | [rust-metal (0001)](../../0001-empty-launch-window/rust-metal/) | This task |
| --- | --- | --- |
| Shader | None | Vertex + fragment functions compiled from source |
| Pipeline | None | `MTLRenderPipelineState` with a BGRA8 color attachment |
| Vertex data | None | Position and color buffers |
| Frame | One clear on layout events | A clear plus a draw on every refresh |
| Synchronization | Not needed | Three-slot semaphore released by the GPU |

A clear is a fixed-function render-pass step, which is why 0001 needed no shader.
A triangle is the first thing that needs a pipeline: the GPU has to run code per
vertex and per fragment.

## How a frame is produced

1. **Compile the shader** once at startup with
   `newLibraryWithSource:options:error:` at
   [src/renderer.rs:75](src/renderer.rs#L75). The source is embedded with
   `include_str!` from [`shaders/triangle.metal`](../shaders/triangle.metal).
2. **Build the pipeline** at [src/renderer.rs:101](src/renderer.rs#L101).
   This combines the two functions and the attachment format. Pipeline creation is
   expensive, so it happens once, never per frame.
3. **Upload vertex data** at [src/renderer.rs:50](src/renderer.rs#L50).
   Two small shared-memory buffers are enough for three vertices.
4. **Wait for a frame slot** at
   [src/renderer.rs:128](src/renderer.rs#L128). The semaphore starts at
   three, matching the three drawables in the pool.
5. **Record the pass** at [src/renderer.rs:139](src/renderer.rs#L139):
   clear the color attachment, set the pipeline, bind both buffers, and issue one
   `drawPrimitives(Triangle, 0, 3)`.
6. **Present and submit** at [src/renderer.rs:161](src/renderer.rs#L161).
7. **Drive it from the display link** at
   [src/layer_view.rs:33](src/layer_view.rs#L33). AppKit gives the view a
   `CADisplayLink`; each `tick:` runs `draw`.

## Ownership notes

- The renderer lives in a `thread_local!` `OnceCell` because Metal objects are not
  `Send`/`Sync` and all rendering happens on the main thread.
- The view owns its `CAMetalLayer` and the display-link target. The target owns
  the link, so the loop cannot outlive what it draws into.
- `DispatchSemaphore::try_acquire` returns a guard; letting it drop signals the
  semaphore. In this task the frame is committed before the function returns, so
  the guard's scope is the frame. Task 0003 will move the release onto the GPU
  completion callback to overlap more frames.

## What this deliberately leaves out

- Vertex shader uniforms, animation, and time.
- Depth testing, MSAA, and sRGB.
- Precompiled `.metallib` and offline shader tooling.
- Pacing refinements such as target-timestamp scheduling or variable refresh rate.

## Verification

- `cargo clippy --all-targets -- -D warnings` passes.
- The window renders continuously; a screenshot on 2026-10-19 showed the RGB
  triangle on the dark blue clear.

## Structure

- `src/main.rs` — app lifecycle, window, menu.
- `src/renderer.rs` — device, pipeline, buffers, and the frame draw.
- `src/layer_view.rs` — layer-hosting view, display link, resize handling.
- `src/app_delegate.rs` — quit after the last window closes.
