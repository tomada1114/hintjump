import AppKit

/// The test process's own event queue, which `swift test` never pumps by itself.
///
/// `swift test` runs no `NSApplication` event loop, so an event posted to this process —
/// or the window server's answer to ordering a window in or out — would sit in the queue
/// and never be dispatched. Draining it by hand is the only way such a test sees either.
@MainActor
enum OwnEventQueue {
    /// Long enough for the window server to deliver an event posted to this process, or
    /// to order a window in or out.
    static let settleTime: TimeInterval = 0.3

    /// Dispatches every event queued for this process until `seconds` have passed, and
    /// returns them in the order they arrived.
    @discardableResult
    static func drain(for seconds: TimeInterval) -> [NSEvent] {
        let application = NSApplication.shared
        let deadline = Date(timeIntervalSinceNow: seconds)
        var events: [NSEvent] = []
        while let event = application.nextEvent(
            matching: .any,
            until: deadline,
            inMode: .default,
            dequeue: true,
        ) {
            events.append(event)
            application.sendEvent(event)
        }
        return events
    }
}
