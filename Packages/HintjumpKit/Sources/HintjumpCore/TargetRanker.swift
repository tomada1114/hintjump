import CoreGraphics

/// The outcome of the clickable filter for one element.
private enum Admission {
    case admitted(CGRect)
    case excluded(TargetExclusion)

    var exclusion: TargetExclusion? {
        switch self {
        case .admitted:
            nil

        case let .excluded(reason):
            reason
        }
    }
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
/// here, and so is the collapse of duplicates among what it admits (``ranking(_:)``).
/// The tier each surviving element gets is one replaceable function,
/// ``TierAssignment``, defaulting to ``FirstCutTiers/tier(_:)``: the rule as #37's
/// target-count measurement revised it (`docs/decisions.md` › "The tier rule after #37's
/// measurement; N stays 16"). Keeping it replaceable means a later revision changes
/// nothing callers receive. Within a tier the order is reading order — top to
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

    /// Why the clickable filter turns the element at `index` away, or `nil` when it
    /// admits the element.
    ///
    /// Exposed so a caller can say why an element it expected is missing — the
    /// measurement of how often the wanted element ranks high needs exactly that. An
    /// admitted element can still be left out as a duplicate of another target; that
    /// depends on the rest of the read and on the rank order, so only ``ranking(_:)``
    /// reports it. `index` must be a valid index of `elements`.
    public static func exclusion(
        ofElementAt index: Int,
        in elements: [ElementSnapshot],
    ) -> TargetExclusion? {
        admission(ofElementAt: index, in: elements).exclusion
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

    /// The index of the element's parent, or `nil` for the root or a parent index that
    /// breaks the pre-order.
    static func parentIndex(
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
        elements[index].actions.contains("AXPress")
            || isClickableByRole(elementAt: index, in: elements)
    }

    /// Whether the element's role alone would let it through the filter — a listed role,
    /// or a row directly in an outline or a table — with or without an `AXPress` action.
    static func isClickableByRole(elementAt index: Int, in elements: [ElementSnapshot]) -> Bool {
        guard let role = elements[index].role else {
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

    /// `sorted` as ranked targets, keeping only the first of each frame and marking the
    /// rest ``TargetExclusion/sameFrame`` in `exclusions`.
    private static func collapsingTwins(
        _ sorted: [Admitted],
        of elements: [ElementSnapshot],
        exclusions: inout [TargetExclusion?],
    ) -> [RankedTarget] {
        var seenFrames = Set<DuplicateTargets.FrameKey>()
        var targets: [RankedTarget] = []
        for target in sorted {
            guard seenFrames.insert(DuplicateTargets.FrameKey(target.frame)).inserted else {
                exclusions[target.index] = .sameFrame
                continue
            }
            targets.append(RankedTarget(
                rank: targets.count + 1,
                tier: target.tier,
                elementIndex: target.index,
                element: elements[target.index],
            ))
        }
        return targets
    }

    /// The clickable subset of `elements`, in rank order, with no two targets for one
    /// spot: ``ranking(_:)``'s targets.
    ///
    /// `elements` is a read's pre-order list (``TreeSnapshot/elements``): index 0 is the
    /// root, whose frame bounds every target — for a `.focusedWindow` read, the window.
    public func rank(_ elements: [ElementSnapshot]) -> [RankedTarget] {
        ranking(elements).targets
    }

    /// The targets of `elements` in rank order, and why every other element is not one.
    ///
    /// The filter's admitted elements lose their duplicates in three steps, each a
    /// ``TargetExclusion``: a pressable group covering half the root that holds another
    /// target (``TargetExclusion/windowSizedGroup``); a cell, or a text field in a cell,
    /// whose nearest row is still a target (``TargetExclusion/insideTargetRow``); and,
    /// once ranked, any target whose frame an earlier target has exactly
    /// (``TargetExclusion/sameFrame``). The survivors keep their order; ranks are
    /// renumbered without gaps. The collapse adds only passes linear in the read, apart
    /// from a walk up from each cell and text field to its row, since a window of about
    /// 1,800 elements has to rank within the 0.3 s budget.
    public func ranking(_ elements: [ElementSnapshot]) -> TargetRanking {
        let admissions = elements.indices.map { Self.admission(ofElementAt: $0, in: elements) }
        var exclusions = admissions.map(\.exclusion)
        guard let windowFrame = elements.first?.frame else {
            return TargetRanking(targets: [], exclusions: exclusions)
        }
        DuplicateTargets.excludeStructural(in: elements, root: windowFrame, exclusions: &exclusions)
        let admitted = elements.indices.compactMap { index -> Admitted? in
            guard exclusions[index] == nil, case let .admitted(frame) = admissions[index] else {
                return nil
            }
            let candidate = TargetCandidate(
                element: elements[index],
                ancestors: Self.ancestors(ofElementAt: index, in: elements),
                windowFrame: windowFrame,
            )
            return Admitted(index: index, frame: frame, tier: assignTier(candidate))
        }
        let targets = Self.collapsingTwins(
            admitted.sorted(by: Admitted.precedes),
            of: elements,
            exclusions: &exclusions,
        )
        return TargetRanking(targets: targets, exclusions: exclusions)
    }
}
