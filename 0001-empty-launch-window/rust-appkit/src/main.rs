use std::process::ExitCode;

use objc2::rc::Retained;
use objc2::runtime::ProtocolObject;
use objc2::{MainThreadMarker, MainThreadOnly, define_class, msg_send, sel};
use objc2_app_kit::{
    NSApplication, NSApplicationActivationPolicy, NSApplicationDelegate, NSBackingStoreType,
    NSColor, NSEvent, NSMenu, NSMenuItem, NSRectFill, NSView, NSWindow, NSWindowStyleMask,
};
use objc2_foundation::{NSObject, NSObjectProtocol, NSPoint, NSRect, NSSize, ns_string};

/// A view that paints the window black and listens for Escape.
///
/// AppKit's `drawRect:` callback runs on the main thread, so this is a direct
/// Rust equivalent of the Swift `GameView`.
struct GameViewIvars;

define_class!(
    // SAFETY: `NSView` is a normal AppKit view with no subclassing requirements,
    // and `GameViewIvars` is a zero-sized type.
    #[unsafe(super = NSView)]
    #[thread_kind = MainThreadOnly]
    #[ivars = GameViewIvars]
    struct GameView;

    impl GameView {
        /// Paint the dirty region black, exactly like the Swift baseline.
        #[unsafe(method(drawRect:))]
        fn draw_rect(&self, dirty_rect: NSRect) {
            NSColor::blackColor().setFill();
            NSRectFill(dirty_rect);
        }

        #[unsafe(method(acceptsFirstResponder))]
        fn accepts_first_responder(&self) -> bool {
            true
        }

        #[unsafe(method(keyDown:))]
        fn key_down(&self, event: &NSEvent) {
            if event.keyCode() == 53 {
                let app = NSApplication::sharedApplication(self.mtm());
                app.terminate(None);
            }
        }
    }
);

impl GameView {
    fn new(mtm: MainThreadMarker, frame: NSRect) -> Retained<Self> {
        let view = Self::alloc(mtm).set_ivars(GameViewIvars);
        // SAFETY: `initWithFrame:` is NSView's designated initializer and the
        // receiver is a freshly allocated GameView.
        unsafe { msg_send![super(view), initWithFrame: frame] }
    }
}

/// The application delegate exists only to quit when the last window closes,
/// matching the Swift variant.
struct AppDelegateIvars;

define_class!(
    // SAFETY: `NSObject` is a normal root class and the delegate has no
    // subclassing requirements.
    #[unsafe(super = NSObject)]
    #[thread_kind = MainThreadOnly]
    #[ivars = AppDelegateIvars]
    struct AppDelegate;

    // SAFETY: `NSObjectProtocol` has no safety requirements.
    unsafe impl NSObjectProtocol for AppDelegate {}

    // SAFETY: `NSApplicationDelegate` has no safety requirements.
    unsafe impl NSApplicationDelegate for AppDelegate {
        #[unsafe(method(applicationShouldTerminateAfterLastWindowClosed:))]
        fn should_terminate_after_last_window_closed(&self, _sender: &NSApplication) -> bool {
            true
        }
    }
);

impl AppDelegate {
    fn new(mtm: MainThreadMarker) -> Retained<Self> {
        let delegate = Self::alloc(mtm).set_ivars(AppDelegateIvars);
        // SAFETY: `init` is NSObject's designated initializer and the receiver is
        // a freshly allocated AppDelegate.
        unsafe { msg_send![super(delegate), init] }
    }
}

/// A programmatic app has no menu bar by default, so ⌘Q would not be handled.
/// Install the minimal application menu needed for the standard Quit item.
fn install_main_menu(mtm: MainThreadMarker, app: &NSApplication) {
    let main_menu = NSMenu::new(mtm);
    let app_menu_item = NSMenuItem::new(mtm);
    let app_menu = NSMenu::new(mtm);
    app_menu_item.setTitle(ns_string!("Rust AppKit"));

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

fn create_window(mtm: MainThreadMarker) -> Retained<NSWindow> {
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

    window.setTitle(ns_string!("Game"));
    window.setContentMinSize(NSSize::new(320.0, 180.0));

    let view = GameView::new(mtm, content_rect);
    window.setContentView(Some(&view));
    window.center();
    window.makeKeyAndOrderFront(None);
    window.makeFirstResponder(Some(&view));

    window
}

fn main() -> ExitCode {
    let Some(mtm) = MainThreadMarker::new() else {
        eprintln!("This program must run on the main thread.");
        return ExitCode::FAILURE;
    };

    let app = NSApplication::sharedApplication(mtm);
    app.setActivationPolicy(NSApplicationActivationPolicy::Regular);
    install_main_menu(mtm, &app);

    let delegate = AppDelegate::new(mtm);
    app.setDelegate(Some(ProtocolObject::from_ref(&*delegate)));

    let _window = create_window(mtm);
    app.activate();
    app.run();

    ExitCode::SUCCESS
}
