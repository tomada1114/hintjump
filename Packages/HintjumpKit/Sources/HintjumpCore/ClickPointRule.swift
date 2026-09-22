import CoreGraphics

/// Where a hint clicks its target: the center of the part of the target the window
/// shows (`docs/decisions.md` › "Clicks are synthesized mouse events at the element's
/// visible center; the pointer stays there").
///
/// The ranker admits an element whose center is inside the window, so a target can
/// still hang off an edge — a row scrolled half out of view. Clicking its own center
/// would then land outside the window, on whatever is behind it.
public enum ClickPointRule {
    /// The center of `frame ∩ root`, or `nil` when the two do not overlap in an area —
    /// disjoint, or touching only along an edge — and the target cannot be clicked.
    public static func point(for frame: CGRect, within root: CGRect) -> CGPoint? {
        let visible = frame.intersection(root)
        guard !visible.isEmpty else {
            return nil
        }
        return CGPoint(x: visible.midX, y: visible.midY)
    }
}
