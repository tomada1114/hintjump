import CoreGraphics

/// Which mouse button a hint clicks with.
///
/// Two cases and never more: a hint does a left click or a right click, nothing else
/// (`docs/decisions.md` › "The actions are left click and right click, nothing else").
/// A `String` raw value so a log line or a config value can name it.
public enum MouseButton: String, Sendable {
    case left
    case right
}

/// Why a click could not be posted.
///
/// ``notTrusted`` is kept apart from ``eventCreationFailed`` because the OS does not keep
/// them apart: without the Accessibility grant a posted event is silently dropped, so
/// the adapter checks the grant first and Core can tell "nothing happened because the
/// grant is missing" from "the OS would not build the event".
public enum ClickError: Error, Equatable, Sendable {
    /// The OS returned no event source or no mouse event to post.
    case eventCreationFailed
    /// This process does not hold the Accessibility grant, so the click was not posted.
    case notTrusted
}

/// A port: click a mouse button at a point on screen.
///
/// Synthesized mouse events live in `CoreGraphics`' event API, which belongs in a
/// `HintjumpPlatform` adapter, so this port is how Core reaches it. Which point to click
/// is a decision and stays in Core; the port only posts. `@MainActor` because its only
/// callers — the overlay's key handling — are, and so the adapter never has to hand an
/// OS object across an isolation boundary.
@MainActor
public protocol ClickPerforming: Sendable {
    /// Posts a press and a release of `button` at `point`, leaving the pointer there.
    ///
    /// `point` is in the Accessibility API's coordinate space — global, origin at the
    /// top-left of the primary display — which is also the event API's, so an element's
    /// frame from ``AccessibilityTreeReading`` needs no conversion on the way here.
    /// Typed so the adapter has to translate the OS's silence into a value Core owns.
    func click(at point: CGPoint, button: MouseButton) throws(ClickError)
}
