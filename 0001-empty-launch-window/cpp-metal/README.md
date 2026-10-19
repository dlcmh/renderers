# Metal Launch Window (C++ / Metal)

Task: [0001 — Empty launch window](../README.md). C++ CPU baseline:
[cpp-appkit](../cpp-appkit/). Swift Metal counterpart:
[swift-metal](../swift-metal/). Rust Metal counterpart:
[rust-metal](../rust-metal/). Repository rules: [AGENTS.md](../../AGENTS.md).

This variant opens a native macOS window and clears its `CAMetalLayer` to dark
blue using Metal from Objective-C++. The Metal objects and frame sequence match
the Swift and Rust variants; the C++ variant uses ARC and Objective-C message
syntax directly.

## Run

From the repository root, with build artifacts under `/tmp/renderers`:

```sh
./scripts/run.sh cpp-metal
```

Or invoke CMake directly:

```sh
cd 0001-empty-launch-window
cmake -S . -B /tmp/renderers/cpp -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build /tmp/renderers/cpp --target cpp-metal
/tmp/renderers/cpp/cpp-metal
```

A centered, resizable 1280×720 window opens with a dark blue surface. Close the
window, press Escape, or press ⌘Q to quit.

## Comparison

| | Swift / Metal | Rust / Metal | C++ / Metal |
| --- | --- | --- | --- |
| Window host | AppKit | AppKit | AppKit |
| Surface | `CAMetalLayer` | `CAMetalLayer` | `CAMetalLayer` |
| GPU API | Metal | Metal | Metal |
| Ownership | ARC | `Retained<ProtocolObject<…>>` | ARC |
| FFI boundary | None | `unsafe` + SAFETY comments | Objective-C++ / ARC |
| Frame loop | event-driven | event-driven | event-driven |
| Content | dark blue clear | dark blue clear | dark blue clear |

All three issue identical Metal commands. C++ is the closest to the Objective-C
API surface: there is no generated binding layer, only the Objective-C++ compiler
bridging the two languages.

## How it works

1. **Create the device and queue** in `applicationDidFinishLaunching:`
   ([src/main.mm:151](src/main.mm#L151) and
   [src/main.mm:158](src/main.mm#L158)).
2. **Install the main menu** so ⌘Q has a standard Quit item
   ([src/main.mm:194](src/main.mm#L194)).
3. **Create the window and `MetalView`** at
   [src/main.mm:180](src/main.mm#L180).
4. **Configure the `CAMetalLayer`** at
   [src/main.mm:44](src/main.mm#L44): BGRA8, opaque, framebuffer-only, and a
   three-drawable pool.
5. **Attach the layer** to the view at
   [src/main.mm:52](src/main.mm#L52). The view is layer-hosting.
6. **Resize in pixels** at [src/main.mm:82](src/main.mm#L82). AppKit reports
   points; a Retina display needs a 2× drawable.
7. **Encode one clear pass** at [src/main.mm:92](src/main.mm#L92). Acquire a
   drawable, create a command buffer, clear the color attachment, end encoding,
   present, and commit.
8. **Render on layout events.** `setFrameSize:`, `viewDidMoveToWindow`, and
   `viewDidChangeBackingProperties` update the drawable and submit a frame. There
   is no display link, so this is not a continuous game loop yet.

No shader or pipeline is needed because a render pass can clear its attachment as
a fixed-function operation.

## Ownership

The project uses ARC for both Metal and AppKit objects:

- `MetalView` keeps `_commandQueue` and `_metalLayer` as strong instance
  variables.
- The `CAMetalLayer` retains the `MTLDevice`.
- A drawable is borrowed for one `render` call, presented, and returned to the
  layer's pool after the GPU finishes.
- The application delegate is kept alive with
  `__attribute__((objc_precise_lifetime))` because `NSApplication.delegate` is
  weak ([src/main.mm:220](src/main.mm#L220)).

There is no manual retain/release and no manual `new`/`delete`.

## Performance

The GPU commands are identical to the Swift and Rust variants, so the clear cost
is the same. C++ adds no runtime abstraction over Metal; the host-side work is
Objective-C message dispatch, just like the other variants. For a static clear,
Metal is not automatically faster than the AppKit CPU path; it becomes valuable
as per-pixel work grows. See the
[Swift Metal performance section](../swift-metal/README.md#is-it-faster) and
[Graphics concepts and portability](../../docs/GRAPHICS-CONCEPTS.md).

## Build and checks

The C++ variants share one CMake project at the task root. The check script runs
format checks, builds both targets with warnings as errors, and builds both with
AddressSanitizer and UndefinedBehaviorSanitizer:

```sh
./scripts/check-cpp.sh
```

## Deliberate omissions

- No shader, pipeline, vertex buffer, or draw call.
- No continuous frame loop or in-flight frame semaphore.
- No menu commands beyond the standard Quit item (⌘Q).
- No input handling beyond Escape, or cross-platform surface abstraction.

## Verification

- Debug and sanitizer builds pass with warnings treated as errors.
- Both C++ binaries launched; the window server reported on-screen windows owned
  by `cpp-appkit` and `cpp-metal` at layer 0 with 1280×752 outer frames.
- A window screenshot captured with Screen Recording permission confirmed the
  dark blue surface on 2026-10-19.

## Structure

- `src/main.mm` — Metal view, render pass, window, lifecycle, and menu.
- The shared CMake project and C++ tooling live one level up.
