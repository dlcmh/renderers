# Empty Game Window (C++ / AppKit)

Task: [0001 — Empty launch window](../README.md). Swift baseline:
[swift-appkit](../swift-appkit/). Rust baseline: [rust-appkit](../rust-appkit/).
GPU counterpart: [cpp-metal](../cpp-metal/). Repository rules:
[AGENTS.md](../../AGENTS.md).

A native macOS window opened from C++ through AppKit. The window is an ordinary
`NSWindow`; a `GameView` subclass paints the content black in `drawRect:` and
quits on Escape or ⌘Q.

The source is **Objective-C++** (`.mm`), not standard C++. AppKit and Metal are
Objective-C APIs, so direct access from C++ requires the Objective-C runtime.
This is the C++ counterpart to the Swift and Rust AppKit variants, with no
cross-platform windowing library in between.

## Run

From the repository root, with build artifacts under `/tmp/renderers`:

```sh
./scripts/run.sh cpp-appkit
```

Or invoke CMake directly:

```sh
cd 0001-empty-launch-window
cmake -S . -B /tmp/renderers/cpp -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build /tmp/renderers/cpp --target cpp-appkit
/tmp/renderers/cpp/cpp-appkit
```

A centered, resizable 1280×720 window opens with a black surface. Close the
window, press Escape, or press ⌘Q to quit.

## The delta from Swift and Rust

| | Swift / AppKit | Rust / AppKit | C++ / AppKit |
| --- | --- | --- | --- |
| AppKit objects | Same | Same | Same |
| Language boundary | Native Swift | `objc2` message sends | Objective-C++ message sends |
| View subclass | Swift class | `define_class!` | `@interface GameView : NSView` |
| Ownership | ARC | `Retained<T>` | ARC |
| Safety | Compiler-enforced | `unsafe` FFI blocks | ARC + compiler warnings |
| Delegate lifetime | Swift local | Rust local | `objc_precise_lifetime` local |
| Rendering | `NSColor` + `NSRectFill` | Same | Same |

The AppKit calls are direct in all three. C++ does not add a runtime layer; it
changes how you name types, declare methods, and manage the delegate lifetime.

## How it works

1. **Create the application and delegate** in `main`, set the regular activation
   policy, and run the app loop
   ([src/main.mm:100](src/main.mm#L100)).
2. **Install a minimal main menu** with the standard Quit item so ⌘Q is
   registered ([src/main.mm:77](src/main.mm#L77)).
3. **Create the window** with the same style mask as the other variants
   ([src/main.mm:56](src/main.mm#L56)).
4. **Own it from C++.** Programmatic windows are released when closed by default;
   `releasedWhenClosed = NO` prevents AppKit from releasing a window whose
   lifetime is managed by ARC ([src/main.mm:64](src/main.mm#L64)).
5. **Install `GameView`**, which fills the dirty rectangle black and handles
   Escape in `keyDown:`
   ([src/main.mm:20](src/main.mm#L20)).
6. **Quit after the last window closes** through the application delegate
   ([src/main.mm:93](src/main.mm#L93)).

## Ownership and safety

The project compiles with ARC, so Objective-C objects are retained and released
automatically. There is no manual `new`/`delete` for AppKit objects.

One subtlety is the application delegate: `NSApplication.delegate` is a weak
reference. The local `delegate` in `main` is marked
`__attribute__((objc_precise_lifetime))` so ARC cannot release it before
`[app run]` returns ([src/main.mm:103](src/main.mm#L103)).

All files compile with `-Wall -Wextra -Wpedantic -Werror`; unused callback
parameters are explicitly discarded with `(void)`. There are no third-party
dependencies or framework abstractions.

## Build and checks

The C++ variants share one CMake project at the task root. The
`scripts/check-cpp.sh` script runs `clang-format --dry-run --Werror`, builds both
targets, and builds both again with AddressSanitizer and
UndefinedBehaviorSanitizer:

```sh
./scripts/check-cpp.sh
```

The sanitizer build is not a runtime substitute for testing the window, but it
does exercise the Objective-C++ code and ARC paths at launch.

## Deliberate omissions

- No rendering beyond AppKit's CPU drawing.
- No menu commands beyond the standard Quit item (⌘Q).
- No cross-platform windowing abstraction.
- No tests; the observable behavior is the window itself.

## Verification

- Debug and sanitizer builds pass with warnings treated as errors.
- Both C++ binaries launched; the window server reported on-screen windows owned
  by `cpp-appkit` and `cpp-metal` at layer 0 with 1280×752 outer frames.
- Screen capture was unavailable because Screen Recording permission was not
  granted; content was verified by code path and window presence.

## Structure

- `src/main.mm` — application lifecycle, view, window, and menu.
- The shared CMake project and C++ tooling live one level up.
