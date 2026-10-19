# Empty Game Window (Rust / AppKit)

Task: [0001 — Empty launch window](../README.md). Swift baseline:
[swift-appkit](../swift-appkit/). GPU counterpart:
[rust-metal](../rust-metal/). Repository rules: [AGENTS.md](../../AGENTS.md).

A native macOS window opened from Rust through AppKit. The window is an ordinary
`NSWindow`; a Rust-defined `NSView` subclass paints the content black in
`drawRect:` and quits on Escape. This is the Rust counterpart to the Swift AppKit
variant, not a wrapper around a windowing framework.

## Run

From this directory:

```sh
cd 0001-empty-launch-window/rust-appkit
cargo run
```

Or from the task workspace:

```sh
cd 0001-empty-launch-window
cargo run -p rust-appkit
```

A centered, resizable 1280×720 window opens with a black surface. Close the
window, press Escape, or press ⌘Q to quit.

## The delta from Swift

| | Swift / AppKit | Rust / AppKit |
| --- | --- | --- |
| AppKit objects | `NSWindow`, `NSView`, `NSColor` | The same Objective-C objects |
| View subclass | Swift class | `define_class!` registers a runtime class |
| Message sends | Swift method dispatch | `objc_msgSend` through `objc2` |
| Ownership | ARC | `Retained<T>` retain/release wrappers |
| Memory safety | Compiler-enforced | `unsafe` FFI blocks with documented invariants |
| Delegate | `NSApplicationDelegate` conformance | `NSApplicationDelegate` protocol impl |
| Rendering | `NSColor.black.setFill()` + `dirtyRect.fill()` | `NSColor.blackColor().setFill()` + `NSRectFill` |
| Runtime behavior | Identical AppKit window | Identical AppKit window |

This is not a performance experiment. Both versions call the same AppKit code; the
difference is the language boundary. Rust gives you memory safety outside the FFI
boundary, but every Objective-C call is still dynamic dispatch and every AppKit
object still needs an explicit ownership story.

## How it works

1. **Assert the main thread.** `MainThreadMarker::new()` fails if the process is
   not on the main thread. AppKit requires one. See
   [src/main.rs:151](src/main.rs#L151).
2. **Create the application** with `NSApplication::sharedApplication(mtm)` and set
   the regular activation policy so the window gets a Dock presence.
3. **Install the application menu.** A programmatic app has no menu bar, so ⌘Q
   would otherwise do nothing. `install_main_menu` adds the standard Quit item
   ([src/main.rs:93](src/main.rs#L93), called at
   [src/main.rs:159](src/main.rs#L159)).
4. **Create the window** with the same style mask as the Swift variant:
   titled, closable, miniaturizable, and resizable
   ([src/main.rs:116](src/main.rs#L116)).
5. **Own the window from Rust.** Programmatic windows are released when closed by
   default. We set `setReleasedWhenClosed(false)` because the Rust `Retained`
   wrapper is the owner ([src/main.rs:137](src/main.rs#L137)).
6. **Install a custom view.** `GameView` overrides `drawRect:` and fills the dirty
   rectangle with black ([src/main.rs:28](src/main.rs#L28)). It also accepts first
   responder and handles Escape in `keyDown:`.
7. **Register an application delegate.** It returns `true` from
   `applicationShouldTerminateAfterLastWindowClosed:` so closing the only window
   quits the process ([src/main.rs:74](src/main.rs#L74)).
8. **Show and run.** `makeKeyAndOrderFront`, `makeFirstResponder`, `activate`, then
   `app.run()` ([src/main.rs:142](src/main.rs#L142)).

## The FFI boundary

`objc2` is a thin binding: it gives Rust access to the Objective-C runtime and the
AppKit classes, but it does not provide an event loop, a windowing abstraction, or
a renderer. That keeps this variant comparable to the Swift code.

The unsafe boundary is deliberately small and visible:

- `define_class!` is unsafe because it registers a class with the Objective-C
  runtime; the SAFETY comment states the superclass and ivar requirements.
- `msg_send!` is unsafe because the selector and argument types are checked by the
  programmer, not by the compiler.
- Every unsafe block has a `// SAFETY:` explanation, enforced by
  `clippy::undocumented_unsafe_blocks`.

`Retained<T>` keeps an Objective-C object alive and releases it on drop. The
window is retained for the lifetime of `main`; the application delegate and view
are retained by their local variables and AppKit references.

## Deliberate omissions

- No menu commands beyond the standard Quit item (⌘Q).
- No rendering layer beyond AppKit's CPU drawing.
- No cross-platform windowing abstraction. This is the macOS platform edge that a
  future shared RHI will sit behind.
- No tests; the observable behavior is the window itself.

## Verification

- `cargo build -p rust-appkit` and
  `cargo clippy -p rust-appkit --all-targets -- -D warnings` pass.
- Launched from the task workspace; the macOS window server reported an on-screen
  window owned by `rust-appkit` at layer 0 with a 1280×752 outer frame.
- Screen capture was unavailable because Screen Recording permission was not
  granted; the black content was verified by code path and window presence.

## Structure

- `src/main.rs` — application lifecycle, window, view, and delegate.
- `Cargo.toml` — crate metadata and objc2 dependencies.
- The shared task workspace and tooling live one level up.
