# 0002 — First triangle

- **Status:** Complete
- **Verified:** 2026-10-19 on macOS 26.6.2, arm64, Rust 1.97.1, Apple Clang
  21.0.0, CMake 4.4.4

Part of the [renderers](../README.md) task series. Repository rules:
[AGENTS.md](../AGENTS.md). Direction: [Strategic direction](../docs/STRATEGY.md).

## Goal

Draw the first actual geometry: a single RGB triangle, redrawn every display
refresh. Task 0001 ended at "clear a drawable"; this task adds the half of the
GPU pipeline a clear pass never needs.

New concepts, compared with [0001](../0001-empty-launch-window/):

| Concept | 0001 | 0002 |
| --- | --- | --- |
| Shader | None | `triangle.metal`: vertex + fragment functions |
| Shader library | None | `MTLLibrary` compiled from source |
| Pipeline state | None | `MTLRenderPipelineState` |
| Vertex data | None | Two `MTLBuffer`s (positions, colors) |
| Draw call | None | `drawPrimitives(Triangle, 0, 3)` |
| Frame loop | Event-driven | `CADisplayLink` on the main run loop |
| Frame pacing | None | A three-slot in-flight semaphore |

## Non-goals

- Animation, uniforms, cameras, depth, or textures.
- Asynchronous pipeline compilation (the first launch compiles the shader on the
  main thread).
- Render graphs, multiple passes, or multiple command buffers per frame.
- A shared RHI. The two variants duplicate their host code deliberately.

## Variants

Maintained stacks only. Swift is frozen per ADR-0015, and there is no CPU/AppKit
variant because a CPU triangle is a rasterizer lesson, not this one.

| Stack | Path | Run |
| --- | --- | --- |
| Rust / Metal | [`rust-metal/`](rust-metal/) | `./scripts/run.sh rust-metal-triangle` |
| C++ / Metal | [`cpp-metal/`](cpp-metal/) | `./scripts/run.sh cpp-metal-triangle` |

## Acceptance criteria

- [x] Both variants build with warnings treated as errors.
- [x] Both open a centered, resizable 1280×720 window.
- [x] Both draw a single triangle with interpolated vertex colors on a dark blue
      clear.
- [x] A window screenshot shows the triangle in both variants.
- [x] The display link drives frames continuously until the window closes.
- [x] Escape and ⌘Q quit.

## Verification

```sh
./scripts/run.sh rust-metal-triangle
./scripts/run.sh cpp-metal-triangle
```

Both windows were captured with `screencapture -l <window-id>` on 2026-10-19 and
showed the same RGB triangle on the dark blue background. `cargo clippy
--all-targets -- -D warnings` and `clang-format --dry-run --Werror` pass.

## Notes

- The shader lives in [`shaders/triangle.metal`](shaders/triangle.metal). The Rust
  variant embeds it with `include_str!`; the C++ variant embeds an identical copy
  as a string literal, because its build does not yet share a resource bundling
  step.
- AppKit issues the display link: `NSView.displayLinkWithTarget:selector:`. The
  `CADisplayLink` class factory method is unavailable on macOS 14+.
- Both variants wait for a frame slot before drawing and release it when the
  command buffer completes. That is the minimal in-flight model; a later task
  will separate pacing from recording.
