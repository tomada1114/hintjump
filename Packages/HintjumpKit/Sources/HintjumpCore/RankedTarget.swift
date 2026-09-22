import CoreGraphics

/// How likely an element is to be the one clicked, coarsely: the ranker's sort key
/// before position.
///
/// Lower is likelier, and ``RankedTarget``s come out ordered by it, so the elements the
/// single-character labels go to (`docs/decisions.md` › "Single-character labels go to
/// the likeliest targets first") are the first tiers' elements. Compare tiers, or sort
/// ``allCases``, rather than relying on declaration order, which is alphabetical.
public enum TargetTier: Int, CaseIterable, Comparable, Sendable {
    /// Links, and buttons that are not ``primary``.
    case linkOrButton = 2
    /// Every other clickable element.
    case other = 4
    /// Text and search fields, tabs, buttons in a toolbar or a dialog, and sidebar rows.
    case primary = 1
    /// Table and outline rows and cells, and a text field inside a row.
    case rowOrCell = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Why an element is not a target.
///
/// ``TargetRanker/exclusion(ofElementAt:in:)`` checks in the order clickable, enabled,
/// framed, large enough, inside the window, and reports the first that fails.
public enum TargetExclusion: String, CaseIterable, Sendable {
    /// The element reports `AXEnabled` as `false`.
    case disabled
    /// The element has no position or size, so there is nowhere to put its label.
    case noFrame
    /// No `AXPress` action and not one of the roles a click is known to work on.
    case notClickable
    /// The element's center is outside the window's frame, or the read's root — the
    /// window — reports no frame at all.
    case outsideWindow
    /// Narrower or shorter than ``TargetRanker/minimumTargetSize``.
    case tooSmall
}

/// What a tier assignment is shown about one element that passed the clickable filter.
///
/// Everything a tier rule could reasonably turn on without reading the tree again: the
/// element, the chain of containers above it, and the window it is in.
public struct TargetCandidate: Equatable, Sendable {
    /// The element being tiered.
    public let element: ElementSnapshot
    /// The element's containers, nearest first; the last is the read's root.
    public let ancestors: [ElementSnapshot]
    /// The frame of the read's root, which for a `.focusedWindow` read is the window.
    public let windowFrame: CGRect

    public init(element: ElementSnapshot, ancestors: [ElementSnapshot], windowFrame: CGRect) {
        self.element = element
        self.ancestors = ancestors
        self.windowFrame = windowFrame
    }
}

/// One element that can take a hint label, with its place in the order labels are
/// handed out — the shape ``TargetRanker`` returns whatever tier rule it runs.
public struct RankedTarget: Equatable, Sendable {
    /// 1 for the likeliest target, counting up without gaps.
    public let rank: Int
    /// The tier the element was assigned.
    public let tier: TargetTier
    /// The element's index in the list that was ranked — the stable handle back to the
    /// read, and to anything an adapter keeps alongside it.
    public let elementIndex: Int
    /// The element itself, as it was read.
    public let element: ElementSnapshot

    public init(rank: Int, tier: TargetTier, elementIndex: Int, element: ElementSnapshot) {
        self.rank = rank
        self.tier = tier
        self.elementIndex = elementIndex
        self.element = element
    }
}
