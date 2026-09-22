/// One target and the label typed to click it.
public struct LabeledTarget<Target> {
    /// One or two characters from the hint character set.
    public let label: String
    /// The target, as it was handed to ``LabelAssigner/assign(_:characters:)``.
    public let target: Target

    /// Pairs `label` with `target`; ``LabelAssigner`` is what keeps labels distinct.
    public init(label: String, target: Target) {
        self.label = label
        self.target = target
    }
}

/// What ``LabelAssigner/assign(_:characters:)`` made of one ranked target list.
public struct LabelAssignment<Target> {
    /// The targets that got a label, in rank order.
    public let labeled: [LabeledTarget<Target>]
    /// The targets past the label supply, in rank order: not hinted, and kept so the
    /// caller can say how many were dropped.
    public let unlabeled: [Target]

    /// The labels in rank order — what ``HintMatcher/init(labels:)`` takes.
    public var labels: [String] {
        labeled.map(\.label)
    }

    /// How many targets got no label.
    public var unlabeledCount: Int {
        unlabeled.count
    }

    /// An assignment as ``LabelAssigner/assign(_:characters:)`` builds it; public so a
    /// test of a caller can hand one in directly.
    public init(labeled: [LabeledTarget<Target>], unlabeled: [Target]) {
        self.labeled = labeled
        self.unlabeled = unlabeled
    }

    /// The target `label` was assigned to, or `nil` when no target has it — what a
    /// ``HintMatcher/Outcome/selected(_:)`` label is turned back into.
    public func target(labeled label: String) -> Target? {
        labeled.first { $0.label == label }?.target
    }
}

extension LabelAssignment: Equatable where Target: Equatable {}
extension LabelAssignment: Sendable where Target: Sendable {}

extension LabeledTarget: Equatable where Target: Equatable {}
extension LabeledTarget: Sendable where Target: Sendable {}
