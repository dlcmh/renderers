import AppKit

/// The window's content view. For now it just paints an empty black surface;
/// this is where the renderer's view will live later.
final class GameView: NSView {
    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()
    }

    override func keyDown(with event: NSEvent) {
        // Escape quits the app.
        if event.keyCode == 53 {
            NSApp.terminate(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentRect = NSRect(x: 0, y: 0, width: 1280, height: 720)

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Game"
        window.contentMinSize = NSSize(width: 320, height: 180)
        window.contentView = GameView(frame: contentRect)
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
