import AppKit
import HintjumpCore

/// Why ``ClickTargetWindow`` refused to hand out a point to click.
enum ClickTargetError: Error, Equatable {
    /// There is no display — no logged-in GUI session.
    case noScreen
    /// Another window covers the target's center, so a click there would not be the test's.
    case notTopmost(expected: Int, actual: Int)
}

/// A content view that records every left or right press it receives.
final class ClickRecordingView: NSView {
    /// One press: which button, and the click count the app would read.
    struct Press: Equatable {
        let button: MouseButton
        let clickCount: Int
    }

    private(set) var presses: [Press] = []

    /// The window belongs to a process that is not active; without this the first click
    /// would only bring it forward instead of reaching the view.
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        presses.append(Press(button: .left, clickCount: event.clickCount))
    }

    override func rightMouseDown(with event: NSEvent) {
        presses.append(Press(button: .right, clickCount: event.clickCount))
    }
}

/// A window the click test owns, so a posted click can land on nothing of the user's.
///
/// Borderless and at `.screenSaver` level, so it sits above every ordinary window at a
/// fixed spot inside the primary display's visible frame. Its content view records each
/// press it receives. ``clickPoint()`` refuses to answer unless the window server says
/// this window is the topmost one at its center — the guard that keeps a click the
/// window failed to catch from reaching whatever is underneath.
@MainActor
final class ClickTargetWindow {
    /// How big the target is, and how far inside the visible frame's corner it sits.
    static let side: CGFloat = 200
    static let inset: CGFloat = 100
    /// Long enough for the window server to show the window or deliver a click.
    static let settleTime: TimeInterval = 0.3

    let recorder = ClickRecordingView()
    private let window: NSWindow

    /// Creates the window and brings it on screen without activating the test process.
    init() throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let screen = try Self.primaryScreen()
        let origin = CGPoint(
            x: screen.visibleFrame.minX + Self.inset,
            y: screen.visibleFrame.minY + Self.inset,
        )
        window = NSWindow(
            contentRect: CGRect(origin: origin, size: CGSize(width: Self.side, height: Self.side)),
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
        )
        // Not owned by an app delegate or a window controller: ARC owns it, so AppKit must
        // not release it a second time on close.
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.backgroundColor = .systemOrange
        window.contentView = recorder
        window.orderFrontRegardless()
        Self.spinRunLoop(for: Self.settleTime)
    }

    /// The primary display: the one whose top-left corner is the port's origin.
    static func primaryScreen() throws -> NSScreen {
        guard let screen = NSScreen.screens.first else {
            throw ClickTargetError.noScreen
        }
        return screen
    }

    /// Dispatches the events the window server queued for this process until `seconds`
    /// have passed. `swift test` runs no `NSApplication` event loop, so without this a
    /// posted click would sit in the queue and never reach ``ClickRecordingView``.
    static func spinRunLoop(for seconds: TimeInterval) {
        let application = NSApplication.shared
        let deadline = Date(timeIntervalSinceNow: seconds)
        while let event = application.nextEvent(
            matching: .any,
            until: deadline,
            inMode: .default,
            dequeue: true,
        ) {
            application.sendEvent(event)
        }
    }

    /// The window's center in the port's coordinate space — global, origin at the top-left
    /// of the primary display — after checking that a click there would reach this window.
    func clickPoint() throws -> CGPoint {
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let topmost = NSWindow.windowNumber(at: center, belowWindowWithWindowNumber: 0)
        guard topmost == window.windowNumber else {
            throw ClickTargetError.notTopmost(expected: window.windowNumber, actual: topmost)
        }
        let primaryHeight = try Self.primaryScreen().frame.height
        return CGPoint(x: center.x, y: primaryHeight - center.y)
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}
