import CoreGraphics
import HintjumpCore
import Testing

/// Where a hint clicks: the center of the part of the target the window shows.
@Suite("ClickPointRule")
struct ClickPointRuleTests {
    /// The window every case below is clipped to.
    static let root = CGRect(x: 0, y: 0, width: 100, height: 100)

    @Test
    func `a target fully inside the window is clicked at its own center`() {
        let frame = CGRect(x: 10, y: 10, width: 20, height: 20)
        #expect(ClickPointRule.point(for: frame, within: Self.root) == CGPoint(x: 20, y: 20))
    }

    @Test(arguments: [
        // Hanging off the left edge: the visible part is x 0 ..< 30.
        (CGRect(x: -10, y: 10, width: 40, height: 20), CGPoint(x: 15, y: 20)),
        // Hanging off the bottom edge: the visible part is y 90 ..< 100.
        (CGRect(x: 40, y: 90, width: 20, height: 30), CGPoint(x: 50, y: 95)),
        // Larger than the window on every side: the window's own center.
        (CGRect(x: -50, y: -50, width: 200, height: 200), CGPoint(x: 50, y: 50)),
    ])
    func `a target partly outside the window is clicked at the center of its visible part`(
        frame: CGRect,
        expected: CGPoint,
    ) {
        #expect(ClickPointRule.point(for: frame, within: Self.root) == expected)
    }

    @Test(arguments: [
        // Entirely outside.
        CGRect(x: 200, y: 200, width: 10, height: 10),
        // Touching the right edge only: the overlap has no width.
        CGRect(x: 100, y: 10, width: 10, height: 10),
        // Touching the top edge only: the overlap has no height.
        CGRect(x: 10, y: -10, width: 10, height: 10),
    ])
    func `a target with no visible part has no click point`(frame: CGRect) {
        #expect(ClickPointRule.point(for: frame, within: Self.root) == nil)
    }
}
