import CoreGraphics

/// One element a hint can be put on, reduced to what showing and clicking it needs.
///
/// No title and no description: the session never needs them, so the contents of
/// someone else's screen stop at the collector and cannot reach a log line.
public struct HintTarget: Equatable, Sendable {
    /// The element's bounds in global, top-left-origin coordinates — what the tag is
    /// placed against.
    public let frame: CGRect
    /// Where a hint clicks it: the center of its visible part (``ClickPointRule``).
    public let clickPoint: CGPoint
    /// `AXRole`, when the element reports one — the only element-level fact a log line
    /// may carry.
    public let role: String?

    public init(frame: CGRect, clickPoint: CGPoint, role: String?) {
        self.frame = frame
        self.clickPoint = clickPoint
        self.role = role
    }
}
