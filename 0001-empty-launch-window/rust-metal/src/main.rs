mod app_delegate;
mod metal_view;

use std::process::ExitCode;

use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2::{MainThreadMarker, MainThreadOnly, sel};
use objc2_app_kit::{
    NSApplication, NSApplicationActivationPolicy, NSBackingStoreType, NSColor, NSMenu, NSMenuItem,
    NSWindow, NSWindowStyleMask,
};
use objc2_foundation::{NSPoint, NSRect, NSSize, ns_string};
use objc2_metal::{MTLCommandQueue, MTLCreateSystemDefaultDevice, MTLDevice};

use app_delegate::AppDelegate;
use metal_view::MetalView;

// MTLCreateSystemDefaultDevice is provided by the Metal framework but its
// symbol resolution also needs CoreGraphics linked into the process.
#[link(name = "CoreGraphics", kind = "framework")]
unsafe extern "C" {}

/// A programmatic app has no menu bar by default, so ⌘Q would not be handled.
/// Install the minimal application menu needed for the standard Quit item.
fn install_main_menu(mtm: MainThreadMarker, app: &NSApplication) {
    let main_menu = NSMenu::new(mtm);
    let app_menu_item = NSMenuItem::new(mtm);
    let app_menu = NSMenu::new(mtm);
    app_menu_item.setTitle(ns_string!("Rust Metal"));

    // SAFETY: `terminate:` is a valid NSApplication action and both strings are
    // valid NSString values.
    let quit_item = unsafe {
        NSMenuItem::initWithTitle_action_keyEquivalent(
            NSMenuItem::alloc(mtm),
            ns_string!("Quit"),
            Some(sel!(terminate:)),
            ns_string!("q"),
        )
    };

    app_menu.addItem(&quit_item);
    app_menu_item.setSubmenu(Some(&app_menu));
    main_menu.addItem(&app_menu_item);
    app.setMainMenu(Some(&main_menu));
}

fn create_window(
    mtm: MainThreadMarker,
    device: &ProtocolObject<dyn MTLDevice>,
    command_queue: Retained<ProtocolObject<dyn MTLCommandQueue>>,
) -> Retained<NSWindow> {
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

    window.setTitle(ns_string!("Metal Game"));
    window.setContentMinSize(NSSize::new(320.0, 180.0));
    window.setBackgroundColor(Some(&NSColor::blackColor()));

    let view = MetalView::new(mtm, content_rect, device, command_queue);
    window.setContentView(Some(&view));
    window.center();
    window.makeKeyAndOrderFront(None);
    window.makeFirstResponder(Some(&view));
    view.render();

    window
}

fn main() -> ExitCode {
    let Some(mtm) = MainThreadMarker::new() else {
        eprintln!("This program must run on the main thread.");
        return ExitCode::FAILURE;
    };

    let Some(device) = MTLCreateSystemDefaultDevice() else {
        eprintln!("No Metal device is available on this Mac.");
        return ExitCode::FAILURE;
    };
    let Some(command_queue) = device.newCommandQueue() else {
        eprintln!("Could not create a Metal command queue.");
        return ExitCode::FAILURE;
    };

    let app = NSApplication::sharedApplication(mtm);
    app.setActivationPolicy(NSApplicationActivationPolicy::Regular);
    install_main_menu(mtm, &app);

    let delegate = AppDelegate::new(mtm);
    app.setDelegate(Some(ProtocolObject::from_ref(&*delegate)));

    let _window = create_window(mtm, &device, command_queue);
    app.activate();
    app.run();

    ExitCode::SUCCESS
}
