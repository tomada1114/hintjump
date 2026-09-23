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
    /// Text and search fields, tabs, buttons in a sheet or a dialog, sidebar rows, and
    /// links in a web page's main content — nothing in a page's banner or navigation.
    case primary = 1
    /// Table and outline rows and cells, and a text field inside a row.
    case rowOrCell = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Why an element is not a target.
///
/// Two stages report these. The clickable filter,
/// ``TargetRanker/exclusion(ofElementAt:in:)``, checks in the order clickable, not a
/// splitter, enabled, framed, large enough, inside the window, and reports the first
/// that fails. Among the
/// elements it admits, ``TargetRanker/ranking(_:)`` then drops the duplicates that would
/// spend a label on a spot another target already covers — a window-sized group first,
/// then pressable content inside a target button or link, then what is inside a target
/// row, then a row hidden under its column header, then a twin of a better-ranked
/// target — since a click lands at the survivor's visible center either way
/// (`docs/decisions.md` › "Clicks are synthesized mouse events at the element's visible
/// center").
public enum TargetExclusion: String, CaseIterable, Sendable {
    /// The element reports `AXEnabled` as `false`.
    case disabled
    /// Admitted only through `AXPress`, not by its role, and inside an `AXButton` or
    /// `AXLink` that is itself a target, with no other control clickable by role between
    /// them: the button's or link's content, such as the icon and the title group of a
    /// Claude Desktop sidebar entry, which Chromium reports as pressable. A click on it
    /// lands inside the control, so the control takes the label.
    case insideTargetControl
    /// An `AXCell`, or an `AXTextField` inside one, whose nearest `AXRow` is itself a
    /// target: the row takes the label. Its center selects the item without starting
    /// Finder's click-to-rename, and a right click there opens that item's menu. A row
    /// dropped afterwards as ``underColumnHeader`` keeps its cells dropped with it.
    case insideTargetRow
    /// The element has no position or size, so there is nowhere to put its label.
    case noFrame
    /// No `AXPress` action and not one of the roles a click is known to work on.
    case notClickable
    /// The element's center is outside the window's frame, or the read's root — the
    /// window — reports no frame at all.
    case outsideWindow
    /// Another target with exactly this frame ranks earlier and keeps the label.
    case sameFrame
    /// An `AXSplitter`, even one that reports `AXPress`: a split view's divider is only
    /// ever dragged, and drag is a non-goal, so pressing it is never a destination. Claude
    /// Desktop's "Resize sidebar" splitter otherwise put a label on the invisible
    /// boundary between its sidebar and its transcript (#115).
    case splitter
    /// Narrower or shorter than ``TargetRanker/minimumTargetSize``.
    case tooSmall
    /// An `AXRow` whose visible center — the point its click lands on — lies inside a
    /// column-header button of its nearest `AXOutline` or `AXTable`: the row scrolled
    /// behind the header, as Finder's list view reads its first one. Its click would
    /// press the header and re-sort the list.
    case underColumnHeader
    /// Admitted only through `AXPress`, not by its role, covering at least half the
    /// read's root, and holding another target: the pressable group every Electron
    /// window wraps its content in, whose center is some unrelated control.
    case windowSizedGroup
}

/// One read's ranking with the reason for everything left out — what a caller explaining
/// a missing element needs, since a duplicate is only a duplicate among the others.
public struct TargetRanking: Equatable, Sendable {
    /// The targets in rank order: exactly what ``TargetRanker/rank(_:)`` returns.
    public let targets: [RankedTarget]
    /// Why the element at each index of the ranked list is not a target, or `nil` at a
    /// target's index; as long as that list.
    public let exclusions: [TargetExclusion?]

    public init(targets: [RankedTarget], exclusions: [TargetExclusion?]) {
        self.targets = targets
        self.exclusions = exclusions
    }
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
