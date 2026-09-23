import CoreGraphics
import HintjumpCore
import Testing

/// The ranker's suites share one set of fixtures, declared here; the suites themselves
/// are nested, one per concern, in its `+Filter`, `+Tiers`, `+Regions`, `+AppShell`,
/// `+Order`, `+Duplicates`, `+ControlContent`, `+ColumnHeaders`, and `+Splitter`
/// extensions.
@Suite("TargetRanker")
enum TargetRankerTests {
    /// A fully specified element, with the defaults that make it a clickable, enabled,
    /// comfortably sized button in the middle of ``windowFrame`` — so each test changes
    /// only the one attribute it is about.
    struct Spec {
        var role: String? = "AXButton"
        var subrole: String?
        var frame: CGRect? = CGRect(x: 100, y: 100, width: 40, height: 20)
        var isEnabled = true
        var actions: [String] = []
        var parent = 0

        func snapshot(depth: Int) -> ElementSnapshot {
            ElementSnapshot(
                role: role,
                subrole: subrole,
                title: nil,
                description: nil,
                frame: frame,
                isEnabled: isEnabled,
                actions: actions,
                depth: depth,
                parentIndex: parent,
            )
        }
    }

    /// The window every tree below is read from: the root of a `.focusedWindow` read.
    static let windowFrame = CGRect(x: 0, y: 0, width: 900, height: 600)

    /// A standard window at ``windowFrame`` followed by `specs`.
    static func tree(_ specs: [Spec]) -> [ElementSnapshot] {
        tree(specs, rootFrame: windowFrame, rootSubrole: "AXStandardWindow")
    }

    /// Builds a pre-order element list whose index 0 is a window with `rootFrame` and
    /// `rootSubrole`, followed by `specs` in order. Each spec's `parent` is an index into
    /// the returned list, so a spec may only name the window (0) or a spec before it.
    static func tree(
        _ specs: [Spec],
        rootFrame: CGRect?,
        rootSubrole: String,
    ) -> [ElementSnapshot] {
        var elements = [
            ElementSnapshot(
                role: "AXWindow",
                subrole: rootSubrole,
                title: nil,
                description: nil,
                frame: rootFrame,
                isEnabled: true,
                actions: ["AXRaise"],
                depth: 0,
                parentIndex: nil,
            ),
        ]
        for spec in specs {
            elements.append(spec.snapshot(depth: elements[spec.parent].depth + 1))
        }
        return elements
    }

    /// A frame of `width` × `height` whose top-left corner is at (`left`, `top`).
    static func rect(
        _ left: CGFloat,
        _ top: CGFloat,
        _ width: CGFloat,
        _ height: CGFloat,
    ) -> CGRect {
        CGRect(x: left, y: top, width: width, height: height)
    }
}
