use objc2::rc::Retained;
use objc2::{MainThreadMarker, MainThreadOnly, define_class, msg_send};
use objc2_app_kit::{NSApplication, NSApplicationDelegate};
use objc2_foundation::{NSObject, NSObjectProtocol};

/// The application delegate exists only to quit when the last window closes.
pub(crate) struct AppDelegateIvars;

define_class!(
    // SAFETY: `NSObject` is a normal root class and the delegate has no
    // subclassing requirements.
    #[unsafe(super = NSObject)]
    #[thread_kind = MainThreadOnly]
    #[ivars = AppDelegateIvars]
    pub(crate) struct AppDelegate;

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
    pub(crate) fn new(mtm: MainThreadMarker) -> Retained<Self> {
        let delegate = Self::alloc(mtm).set_ivars(AppDelegateIvars);
        // SAFETY: `init` is NSObject's designated initializer and the receiver is
        // a freshly allocated AppDelegate.
        unsafe { msg_send![super(delegate), init] }
    }
}
