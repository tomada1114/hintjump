import CoreGraphics

/// The outcome of the clickable filter for one element.
private enum Admission {
    case admitted(CGRect)
    case excluded(TargetExclusion)
}

/// An element that passed the filter, with what its place in the order is decided by.
private struct Admitted {
    let index: Int
    let frame: CGRect
    let tier: TargetTier

    /// Tier first; then reading order by center, so items of different heights centered
    /// on one toolbar line read left to right; then tree order, so no two targets tie.
    static func precedes(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.tier != rhs.tier {
            return lhs.tier < rhs.tier
        }
        if lhs.frame.midY != rhs.frame.midY {
            return lhs.frame.midY < rhs.frame.midY
        }
        if lhs.frame.midX != rhs.frame.midX {
            return lhs.frame.midX < rhs.frame.midX
        }
        return lhs.index < rhs.index
    }
}

/// Turns one read of a window's tree into the elements that can be clicked, likeliest
/// first — the order single- and two-character labels are handed out in.
///
/// Two separable steps. The clickable filter (``exclusion(ofElementAt:in:)``) is fixed
/// here. The tier each surviving element gets is one replaceable function,
/// ``TierAssignment``, defaulting to ``FirstCutTiers/tier(_:)``: the first-cut weights are a
/// guess the target-count measurement exists to correct, and correcting them must not
/// change what callers receive. Within a tier the order is reading order — top to
/// bottom by the element's center, then left to right, then tree order — so the same
/// list always ranks the same way.
public struct TargetRanker: Sendable {
    /// Maps a candidate to its tier. `@Sendable` so a ranker can be built on one actor
    /// and used on another.
    public typealias TierAssignment = @Sendable (TargetCandidate) -> TargetTier

    /// The smallest width and height, in points, an element can have and still be a
    /// target: anything smaller cannot carry a readable label.
    public static let minimumTargetSize: CGFloat = 8

    /// Roles a click is known to work on even when the element lists no `AXPress`.
    static let clickableRoles: Set<String> = [
        "AXButton", "AXCell", "AXCheckBox", "AXComboBox", "AXDisclosureTriangle",
        "AXIncrementor", "AXLink", "AXMenuButton", "AXPopUpButton", "AXRadioButton",
        "AXSearchField", "AXSlider", "AXTab", "AXTextArea", "AXTextField",
    ]

    /// The containers an `AXRow` must sit directly in to be clickable.
    static let rowContainerRoles: Set<String> = ["AXOutline", "AXTable"]

    private let assignTier: TierAssignment

    /// A ranker whose tiers come from `assignTier`.
    public init(assignTier: @escaping TierAssignment = FirstCutTiers.tier) {
        self.assignTier = assignTier
    }

    /// Why the element at `index` is not a target, or `nil` when it is one.
    ///
    /// Exposed so a caller can say why an element it expected is missing — the
    /// measurement of how often the wanted element ranks high needs exactly that.
    /// `index` must be a valid index of `elements`.
    public static func exclusion(
        ofElementAt index: Int,
        in elements: [ElementSnapshot],
    ) -> TargetExclusion? {
        switch admission(ofElementAt: index, in: elements) {
        case .admitted:
            nil

        case let .excluded(reason):
            reason
        }
    }

    /// The element's containers, nearest first, following ``ElementSnapshot/parentIndex``.
    ///
    /// A parent index that does not precede its child breaks the pre-order the port
    /// promises; it ends the chain there rather than risking a cycle.
    static func ancestors(
        ofElementAt index: Int,
        in elements: [ElementSnapshot],
    ) -> [ElementSnapshot] {
        var chain: [ElementSnapshot] = []
        var current = index
        while let parent = parentIndex(ofElementAt: current, in: elements) {
            chain.append(elements[parent])
            current = parent
        }
        return chain
    }

    private static func parentIndex(
        ofElementAt index: Int,
        in elements: [ElementSnapshot],
    ) -> Int? {
        guard let parent = elements[index].parentIndex, parent >= 0, parent < index else {
            return nil
        }
        return parent
    }

    private static func admission(
        ofElementAt index: Int,
        in elements: [ElementSnapshot],
    ) -> Admission {
        let element = elements[index]
        guard isClickable(elementAt: index, in: elements) else {
            return .excluded(.notClickable)
        }
        guard element.isEnabled else {
            return .excluded(.disabled)
        }
        guard let frame = element.frame else {
            return .excluded(.noFrame)
        }
        guard frame.width >= minimumTargetSize, frame.height >= minimumTargetSize else {
            return .excluded(.tooSmall)
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        guard let windowFrame = elements.first?.frame, windowFrame.contains(center) else {
            return .excluded(.outsideWindow)
        }
        return .admitted(frame)
    }

    private static func isClickable(elementAt index: Int, in elements: [ElementSnapshot]) -> Bool {
        let element = elements[index]
        if element.actions.contains("AXPress") {
            return true
        }
        guard let role = element.role else {
            return false
        }
        if clickableRoles.contains(role) {
            return true
        }
        guard role == "AXRow", let parent = parentIndex(ofElementAt: index, in: elements) else {
            return false
        }
        return rowContainerRoles.contains(elements[parent].role ?? "")
    }

    /// The clickable subset of `elements`, in rank order.
    ///
    /// `elements` is a read's pre-order list (``TreeSnapshot/elements``): index 0 is the
    /// root, whose frame bounds every target — for a `.focusedWindow` read, the window.
    public func rank(_ elements: [ElementSnapshot]) -> [RankedTarget] {
        guard let windowFrame = elements.first?.frame else {
            return []
        }
        let admitted = elements.indices.compactMap { index -> Admitted? in
            guard case let .admitted(frame) = Self.admission(ofElementAt: index, in: elements)
            else {
                return nil
            }
            let candidate = TargetCandidate(
                element: elements[index],
                ancestors: Self.ancestors(ofElementAt: index, in: elements),
                windowFrame: windowFrame,
            )
            return Admitted(index: index, frame: frame, tier: assignTier(candidate))
        }
        return admitted.sorted(by: Admitted.precedes).enumerated().map { offset, target in
            RankedTarget(
                rank: offset + 1,
                tier: target.tier,
                elementIndex: target.index,
                element: elements[target.index],
            )
        }
    }
}
