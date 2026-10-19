# Metal Launch Window (Swift / Metal)

Task: [0001 — Empty launch window](../README.md). CPU baseline:
[swift-appkit](../swift-appkit/). Repository rules: [AGENTS.md](../../AGENTS.md).

This variant opens the same kind of window as the AppKit baseline, but the pixels
come from the GPU. AppKit still creates the window and runs the event loop; a
`CAMetalLayer` replaces the view's ordinary backing store, and a Metal render pass
clears the layer's next drawable to dark blue.

The important shift is **what `draw(_:)` means**. In the baseline, AppKit asks the
view to paint into a backing store. Here, we ask the layer for a drawable texture,
encode GPU commands that write to it, and then present it to Core Animation.

## The delta at a glance

| | [AppKit baseline](../swift-appkit/) | Metal variant |
| --- | --- | --- |
| Window and event loop | AppKit | AppKit (unchanged) |
| Surface | AppKit-managed backing layer | `CAMetalLayer` drawable pool |
| Pixel producer | Core Graphics fill in `draw(_:)` | GPU render pass |
| Main APIs | `NSView`, `NSColor` | `MTLDevice`, `MTLCommandQueue`, `CAMetalLayer`, render pass |
| Content | Black | Dark blue |
| Setup cost | Tiny | Device, queue, layer, pass, command buffer |
| Scales to | Simple 2D drawing | Geometry, shaders, compute, post-processing |

Metal is not a windowing toolkit and it does not replace `NSWindow`. It replaces
the part of the draw path that produces pixels.

## Mental model

```text
NSWindow
  └── MetalView (NSView)
        └── CAMetalLayer                  ← the GPU-visible surface
              └── drawable pool           ← textures the window server can show
                    ▲
                    │ render into one texture
                    │
MTLDevice ── MTLCommandQueue ── MTLCommandBuffer ── render pass (clear)
                                                        │
                                              commandBuffer.present(drawable)
                                                        │
                                              Core Animation composites
```

Three lifetimes matter:

- The **device** and **command queue** are long-lived; create them once.
- A **command buffer** represents one unit of submitted GPU work.
- A **drawable** is a texture borrowed from the layer's pool. Present it, then
  let it return to the pool; do not keep rendering into it after presentation.

## Run

```sh
cd 0001-empty-launch-window/swift-metal
swift run
```

A centered, resizable 1280×720 window opens with a dark blue surface. Close it,
press Escape, or press ⌘Q to quit.

## How one frame is produced

1. **Create the GPU device** with `MTLCreateSystemDefaultDevice()` at
   [main.swift:138](Sources/MetalLaunchWindow/main.swift#L138). This is the
   process's handle to the GPU.
2. **Create one command queue** at
   [main.swift:145](Sources/MetalLaunchWindow/main.swift#L145). Command buffers
   submitted to a queue execute in order; reuse the queue for every frame.
3. **Give the view a `CAMetalLayer`** at
   [main.swift:30](Sources/MetalLaunchWindow/main.swift#L30). The layer is the
   bridge between AppKit's view hierarchy and Metal's drawable textures. Setting
   `wantsLayer` and assigning the layer makes this a layer-hosting view.
4. **Resize the drawable in pixels, not points**, at
   [main.swift:76](Sources/MetalLaunchWindow/main.swift#L76). A 1280×720 window on
   a 2× Retina display needs a 2560×1440 drawable.
5. **Acquire a drawable** with `nextDrawable()` at
   [main.swift:92](Sources/MetalLaunchWindow/main.swift#L92). This blocks only if
   the pool has no free drawable; the current app renders infrequently, so it
   effectively never waits.
6. **Describe and encode the render pass** at
   [main.swift:99](Sources/MetalLaunchWindow/main.swift#L99) and
   [main.swift:105](Sources/MetalLaunchWindow/main.swift#L105). `loadAction =
   .clear` tells the GPU not to load the texture's previous contents; the clear
   color is written as part of the pass.
7. **Present and submit** at
   [main.swift:115](Sources/MetalLaunchWindow/main.swift#L115). `present` hands
   the drawable to Core Animation; `commit` sends the command buffer to the GPU.
8. **Render again on layout events**: the view calls `render()` when it moves to a
   window, when its frame changes, when the display scale changes, and once after
   the window is ordered front (see the overrides starting at
   [main.swift:56](Sources/MetalLaunchWindow/main.swift#L56)).

There is no shader, pipeline state, vertex buffer, or draw call yet. Clearing is a
fixed-function render-pass operation, which is why this first Metal frame can be
complete without a `.metal` file. That is also the boundary of this task: the next
concept is a pipeline and a draw call.

## The old way and the new way, side by side

The AppKit version produces a frame when AppKit calls:

```swift
// swift-appkit/Sources/EmptyGameWindow/main.swift
override func draw(_ dirtyRect: NSRect) {
    NSColor.black.setFill()
    dirtyRect.fill()
}
```

The Metal version explicitly acquires, encodes, and presents:

```swift
// swift-metal/Sources/MetalLaunchWindow/main.swift (condensed)
guard let drawable = metalLayer.nextDrawable(),
      let commandBuffer = commandQueue.makeCommandBuffer() else { return }

let pass = MTLRenderPassDescriptor()
pass.colorAttachments[0].texture = drawable.texture
pass.colorAttachments[0].loadAction = .clear
pass.colorAttachments[0].storeAction = .store
pass.colorAttachments[0].clearColor = clearColor

guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
    return
}
encoder.endEncoding()

commandBuffer.present(drawable)
commandBuffer.commit()
```

The baseline is shorter because AppKit owns both the surface and the drawing
model. The Metal version is longer because it makes the surface, synchronization,
and submission explicit—the same things a renderer eventually needs to control.

## Is it faster?

Not for this workload, necessarily. For a uniform full-window fill, the AppKit
version is already cheap, and Metal adds setup, command encoding, driver work, and
a pool of extra textures. On a 1280×720 window each BGRA drawable is about
3.5 MiB; three drawables plus the window's own backing store is real memory. A
tiny clear does not need that machinery.

The GPU path starts to win when the work per pixel grows:

- **Parallelism:** thousands of fragments can be processed concurrently instead
  of a serial CPU fill.
- **Offload:** the CPU can spend its time on game logic while the GPU renders.
- **Specialized hardware:** blending, depth testing, texture sampling, and
  post-processing are fixed-function or massively parallel operations.
- **Frame pacing:** multiple in-flight frames let CPU encoding overlap GPU
  execution. That benefit requires a continuous loop and synchronization, which
  this event-driven example deliberately does not have yet.

So the honest claim is: **this is the foundation for a faster path, not a faster
empty window**. It removes the CPU from the per-pixel loop and exposes the
submission model that later rendering work depends on.

## Why `CAMetalLayer` instead of `MTKView`?

`MTKView` is MetalKit's convenience subclass. It owns a `CAMetalLayer`, drives a
draw loop, and calls a delegate. It is a good production choice when you do not
need to see the plumbing.

This variant uses `CAMetalLayer` directly so the teaching code exposes:

- where the device and queue come from,
- how a drawable is acquired,
- how a render pass is configured,
- when presentation happens,
- and how window resize and Retina scale affect the drawable.

Once those are clear, `MTKView` is mostly a reduction in boilerplate. See
[ADR-0006](../../docs/DECISIONS.md#adr-0006--teach-with-cametallayer-not-mtkview).

## What this deliberately leaves out

- **A shader pipeline and draw call.** Those arrive with geometry in the next
  task.
- **A continuous frame loop.** This app renders on window events, not at 60/120 Hz.
  Adding a display link also requires in-flight frame limiting so the CPU does not
  race ahead of the GPU.
- **A semaphore for drawable reuse.** Safe to omit while rendering is event-driven;
  required once frames are submitted continuously.
- **Depth/stencil, sRGB, HDR/EDR, and color management.**
- **A cross-platform surface abstraction.** The window/device/surface boundary is
  where a future Vulkan, D3D12, or WebGPU backend would plug in; the command
  submission concepts are similar even when the names differ.

## Cross-platform mapping

Metal is Apple-only, but the concepts are not. Rough equivalents:

| Concept | Metal | Vulkan | D3D12 | WebGPU |
| --- | --- | --- | --- | --- |
| GPU device | `MTLDevice` | `VkDevice` | `ID3D12Device` | `GPUDevice` |
| Command submission | `MTLCommandQueue` | `VkQueue` | command queue | `GPUQueue` |
| Surface/drawable pool | `CAMetalLayer` | swapchain | swapchain | canvas/swapchain |
| Render pass | `MTLRenderPassDescriptor` | render pass | render target | render pass |
| Command recording | `MTLRenderCommandEncoder` | command buffer | command list | command encoder |

That is why this task is useful beyond macOS: the sequence—acquire a surface
image, record a pass, submit, present—is the core of every modern graphics API.

## Status

Complete and verified on 2026-10-19 (macOS 26.6.2, arm64, Swift 6.3.3). A clean
`swift build` succeeds with no warnings. The window server reported an on-screen
window owned by `MetalLaunchWindow` with layer 0 and a 1280×752 outer frame.
Screen capture was unavailable because Screen Recording permission was not
granted, so the dark blue content was verified by code path and window presence,
not by a screenshot.

## Structure

- `Sources/MetalLaunchWindow/main.swift` — app delegate, `CAMetalLayer`-backed
  `MetalView`, command queue, render pass, and window lifecycle.
- `Package.swift` — SwiftPM executable definition with no dependencies.
