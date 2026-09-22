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
/// Stateless and retains no OS object, so nothing here can cross an isolation boundary.
public struct CGEventClickPerformer: ClickPerforming {
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

    public init() {
        // Stateless: every click builds and posts its own events.
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
        press.post(tap: .cghidEventTap)
        release.post(tap: .cghidEventTap)
    }
}
