import ApplicationServices
import HintjumpCore

/// The `CoreGraphics`-backed adapter for ``HintjumpCore/ClickPerforming``: a synthesized
/// mouse press and release, posted at the HID level.
///
/// Why a synthesized event rather than `AXPress`/`AXShowMenu`: it clicks every element
/// kind the same way, right clicks included (`docs/decisions.md` › "Clicks are
/// synthesized mouse events at the element's visible center; the pointer stays there").
/// The pointer is left at the click point on purpose — moving it back would race the
/// target app's own handling of the click.
///
/// Retains no OS object, so nothing here can cross an isolation boundary.
public struct CGEventClickPerformer: ClickPerforming {
    /// Where the synthesized events are posted.
    ///
    /// The product always posts at the HID level, which is what moves the pointer and lets
    /// the window server route the click to whatever window is under the point. The
    /// local-machine test posts the very same events to its own process instead, so it can
    /// read back what was built without moving the pointer or clicking anything of the
    /// developer's; whether the HID route lands on the right window is left to the
    /// end-to-end check, which runs where no one is working.
    enum Delivery: Equatable {
        /// The HID event tap: the pointer moves, and the topmost window at the point gets
        /// the click. What ``init()`` uses.
        case hidSystem
        /// Straight into one process's event queue: the pointer stays put and no other
        /// process sees the events.
        case process(pid_t)
    }

    /// The event types and the `CGMouseButton` a ``HintjumpCore/MouseButton`` translates to.
    private struct EventKinds {
        let press: CGEventType
        let release: CGEventType
        let button: CGMouseButton

        init(_ button: MouseButton) {
            switch button {
            case .left:
                (press, release, self.button) = (.leftMouseDown, .leftMouseUp, .left)

            case .right:
                (press, release, self.button) = (.rightMouseDown, .rightMouseUp, .right)
            }
        }
    }

    /// How this performer posts; always ``Delivery/hidSystem`` outside the tests.
    let delivery: Delivery

    public init() {
        self.init(delivery: .hidSystem)
    }

    /// A performer posting through `delivery`; internal, for the local-machine test.
    init(delivery: Delivery) {
        self.delivery = delivery
    }

    private static func event(
        _ source: CGEventSource,
        _ type: CGEventType,
        _ point: CGPoint,
        _ button: CGMouseButton,
    ) -> CGEvent? {
        CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: button,
        )
    }

    /// Posts `button`'s down and up events at `point`.
    ///
    /// Throws ``HintjumpCore/ClickError/notTrusted`` before building anything when the
    /// Accessibility grant is missing, because a post without it is dropped with no
    /// error at all; throws ``HintjumpCore/ClickError/eventCreationFailed`` when the OS
    /// returns no source or no event.
    public func click(at point: CGPoint, button: MouseButton) throws(ClickError) {
        guard AXIsProcessTrusted() else {
            throw .notTrusted
        }
        let kinds = EventKinds(button)
        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let press = Self.event(source, kinds.press, point, kinds.button),
            let release = Self.event(source, kinds.release, point, kinds.button)
        else {
            throw .eventCreationFailed
        }
        // Each click is a first click: without this, a second hint typed within the
        // double-click interval at the same spot would reach the app as a double click.
        press.setIntegerValueField(.mouseEventClickState, value: 1)
        release.setIntegerValueField(.mouseEventClickState, value: 1)
        post(press)
        post(release)
    }

    private func post(_ event: CGEvent) {
        switch delivery {
        case .hidSystem:
            event.post(tap: .cghidEventTap)

        case let .process(pid):
            event.postToPid(pid)
        }
    }
}
