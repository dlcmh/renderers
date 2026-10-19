#import <Cocoa/Cocoa.h>

static constexpr unsigned short kEscapeKeyCode = 53;

/// The window's content view. It paints the content black on the CPU, matching
/// the Swift and Rust AppKit variants.
@interface GameView : NSView
@end

@implementation GameView

- (BOOL)isOpaque {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor blackColor] setFill];
    NSRectFill(dirtyRect);
}

- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == kEscapeKeyCode) {
        [NSApp terminate:nil];
        return;
    }
    [super keyDown:event];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@interface AppDelegate () {
    NSWindow *_window;
}

- (void)installMainMenu;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [self installMainMenu];

    NSRect contentRect = NSMakeRect(0.0, 0.0, 1280.0, 720.0);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

    _window = [[NSWindow alloc] initWithContentRect:contentRect
                                          styleMask:style
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    _window.title = @"Game";
    _window.contentMinSize = NSMakeSize(320.0, 180.0);

    // We own the window from C++; AppKit must not release it when it closes.
    _window.releasedWhenClosed = NO;

    GameView *view = [[GameView alloc] initWithFrame:contentRect];
    _window.contentView = view;
    [_window center];
    [_window makeKeyAndOrderFront:nil];
    [_window makeFirstResponder:view];

    [NSApp activate];
}

// A programmatic AppKit app starts with no menu bar. Without the Quit item,
// Command-Q is never registered as a key equivalent.
- (void)installMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] init];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];

    appMenuItem.title = NSProcessInfo.processInfo.processName;
    [appMenu addItem:quitItem];
    appMenuItem.submenu = appMenu;
    [mainMenu addItem:appMenuItem];
    NSApp.mainMenu = mainMenu;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        __attribute__((objc_precise_lifetime)) AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
        // Keep the delegate alive for the whole run loop. NSApplication's
        // delegate property is weak.
        (void)delegate;
    }
    return 0;
}
