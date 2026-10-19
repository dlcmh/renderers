# First Triangle (C++ / Metal)

Task: [0002 — First triangle](../README.md). Rust counterpart:
[rust-metal](../rust-metal/). Shared shader:
[triangle.metal](../shaders/triangle.metal). Repository rules:
[AGENTS.md](../../AGENTS.md).

An RGB triangle drawn every display refresh, from Objective-C++, directly against
Metal.

## Run

From the repository root, with build artifacts under `/tmp/renderers`:

```sh
./scripts/run.sh cpp-metal-triangle
```

Or with CMake directly:

```sh
cmake -S 0002-first-triangle -B /tmp/renderers/0002-cpp -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build /tmp/renderers/0002-cpp
/tmp/renderers/0002-cpp/cpp-metal-triangle
```

A triangle with red, green, and blue vertices appears on the dark blue clear. Close
the window, press Escape, or press ⌘Q to quit.

## Comparison with the Rust variant

| | Rust / Metal | C++ / Metal |
| --- | --- | --- |
| Binding style | `objc2` message sends | Objective-C message sends |
| Ownership | `Retained<T>` lifetimes | ARC |
| Frame loop | `CADisplayLink` from `NSView` | `CADisplayLink` from `NSView` |
| Shader source | `include_str!` of `triangle.metal` | Identical string literal |
| In-flight limit | `DispatchSemaphore` | `dispatch_semaphore_t` |
| Errors | `Result<_, String>` | `NSError *` with `NSLog` |

The rendered output is identical. The difference is where the host language puts
the safety: Rust makes the renderer a `thread_local!`, while C++ relies on ARC and
an associated object to keep the display link alive.

## How a frame is produced

1. **Prepare the renderer** in `-[Renderer prepare]`
   ([src/main.mm:55](src/main.mm#L55)): device, queue, shader library,
   pipeline, two buffers, and the semaphore.
2. **Compile and build the pipeline** at
   [src/main.mm:70](src/main.mm#L70) and
   [src/main.mm:90](src/main.mm#L90).
3. **Record and submit** a frame in `-[Renderer drawInLayer:]`
   ([src/main.mm:123](src/main.mm#L123)): wait for a slot, clear, set
   the pipeline, bind two vertex buffers, draw three vertices, present, commit.
4. **Drive it with the display link** at
   [src/main.mm:241](src/main.mm#L241). The link targets the view itself,
   and the view redraws on each `tick:`.

## Ownership notes

- `NSView`'s `displayLinkWithTarget:selector:` returns a link that AppKit only
  weakly retains. The view stores it as an associated object with
  `OBJC_ASSOCIATION_RETAIN_NONATOMIC` so it lives as long as the view.
- The renderer is created in `applicationDidFinishLaunching:` and retained by the
  view, so it outlives the window.
- In-flight frames are limited by a dispatch semaphore released by the command
  buffer's completion handler, not by the recording code.

## What this deliberately leaves out

- Vertex uniforms, animation, and time.
- Depth testing, MSAA, and sRGB.
- A precompiled `.metallib` or an offline shader pipeline.
- Sharing the shader file with the build instead of embedding an identical copy.

## Verification

- The CMake build compiles with `-Wall -Wextra -Wpedantic -Werror`.
- `clang-format --dry-run --Werror` passes.
- The window renders continuously; a screenshot on 2026-10-19 showed the RGB
  triangle on the dark blue clear.

## Structure

- `src/main.mm` — renderer, Metal view, display link, window, and menu.
