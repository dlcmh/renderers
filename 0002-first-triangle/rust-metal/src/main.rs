//! Task 0002: an RGB triangle, drawn every display refresh.
//!
//! Compared with task 0001, this adds the half of the GPU pipeline that a clear
//! pass does not need: a shader library, a render pipeline, vertex buffers, and
//! a draw call. It also adds a frame loop, because a drawable pool and an
//! in-flight semaphore only matter once frames overlap.

mod app_delegate;
mod layer_view;
mod renderer;

use std::process::ExitCode;

use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2::{MainThreadMarker, MainThreadOnly};
use objc2_app_kit::{
    NSApplication, NSApplicationActivationPolicy, NSBackingStoreType, NSColor, NSMenu, NSMenuItem,
    NSWindow, NSWindowStyleMask,
};
use objc2_foundation::{NSPoint, NSRect, NSSize, ns_string};
use objc2_metal::MTLPixelFormat;

use app_delegate::AppDelegate;
use layer_view::LayerView;
use renderer::renderer;

// The shader source is compiled into the executable so the pipeline setup and
// the shader can be read side by side. The same file lives at
// `../shaders/triangle.metal` and is shared with the C++ variant.
const SHADER_SOURCE: &str = include_str!("../../shaders/triangle.metal");

// Must match the CAMetalLayer pixel format; the pipeline validates it.
const PIXEL_FORMAT: MTLPixelFormat = MTLPixelFormat::BGRA8Unorm;

/// A programmatic AppKit app has no menu bar, so install the standard Quit item
/// that makes ⌘Q work.
fn install_main_menu(mtm: MainThreadMarker, app: &NSApplication) {
    let main_menu = NSMenu::new(mtm);
    let app_menu_item = NSMenuItem::new(mtm);
    let app_menu = NSMenu::new(mtm);
    app_menu_item.setTitle(ns_string!("Rust Triangle"));

    // SAFETY: `terminate:` is a valid NSApplication action and both strings are
    // valid NSString values.
    let quit_item = unsafe {
        NSMenuItem::initWithTitle_action_keyEquivalent(
            NSMenuItem::alloc(mtm),
            ns_string!("Quit"),
            Some(objc2::sel!(terminate:)),
            ns_string!("q"),
        )
    };

    app_menu.addItem(&quit_item);
    app_menu_item.setSubmenu(Some(&app_menu));
    main_menu.addItem(&app_menu_item);
    app.setMainMenu(Some(&main_menu));
}

fn create_window(mtm: MainThreadMarker) -> Option<Retained<NSWindow>> {
    let content_rect = NSRect::new(NSPoint::new(0.0, 0.0), NSSize::new(1280.0, 720.0));

    // SAFETY: The window is allocated and initialized on the main thread with a
    // valid content rectangle and style mask.
    let window = unsafe {
        NSWindow::initWithContentRect_styleMask_backing_defer(
            NSWindow::alloc(mtm),
            content_rect,
            NSWindowStyleMask::Titled
                | NSWindowStyleMask::Closable
                | NSWindowStyleMask::Miniaturizable
                | NSWindowStyleMask::Resizable,
            NSBackingStoreType::Buffered,
            false,
        )
    };

    // We own the window from Rust; AppKit must not release it when it closes.
    // SAFETY: The window was created above and is not managed by a window
    // controller.
    unsafe { window.setReleasedWhenClosed(false) };

    window.setTitle(ns_string!("Triangle"));
    window.setContentMinSize(NSSize::new(320.0, 180.0));
    window.setBackgroundColor(Some(&NSColor::blackColor()));

    let renderer = renderer()?;
    let device: &ProtocolObject<dyn objc2_metal::MTLDevice> = &renderer.device;
    let view = LayerView::new(mtm, content_rect, device, PIXEL_FORMAT)?;
    window.setContentView(Some(&view));
    window.center();
    window.makeKeyAndOrderFront(None);
    window.makeFirstResponder(Some(&view));

    Some(window)
}

fn main() -> ExitCode {
    let Some(mtm) = MainThreadMarker::new() else {
        eprintln!("This program must run on the main thread.");
        return ExitCode::FAILURE;
    };

    if renderer().is_none() {
        return ExitCode::FAILURE;
    }

    let app = NSApplication::sharedApplication(mtm);
    app.setActivationPolicy(NSApplicationActivationPolicy::Regular);
    install_main_menu(mtm, &app);

    let delegate = AppDelegate::new(mtm);
    app.setDelegate(Some(ProtocolObject::from_ref(&*delegate)));

    let Some(window) = create_window(mtm) else {
        eprintln!("Could not create the triangle window.");
        return ExitCode::FAILURE;
    };
    app.activate();

    // AppKit's run loop overtakes this thread; `run` returns only after
    // terminate. Avoid warnings about the unused binding and keep the window
    // alive until then.
    let run = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| app.run()));
    let _ = &window;
    if run.is_err() {
        return ExitCode::FAILURE;
    }

    ExitCode::SUCCESS
}
