import HintjumpCore

/// The fake every Core test of ``HintTargetCollecting`` uses: answers every `collect`
/// with the one result it was built with, and records which apps it was asked about
/// (`.claude/rules/testing.md` › Fakes, not mocks). `@MainActor`, like the port.
@MainActor
final class FakeHintTargetCollector: HintTargetCollecting {
    /// Every app `collect` was called with, in order.
    private(set) var collectedApps: [FrontmostApp] = []
    private let answer: Result<TargetSet, AccessibilityReadError>

    /// Answers every call with `set`.
    init(answering set: TargetSet) {
        answer = .success(set)
    }

    /// Throws `error` from every call.
    init(throwing error: AccessibilityReadError) {
        answer = .failure(error)
    }

    func collect(from app: FrontmostApp) throws -> TargetSet {
        collectedApps.append(app)
        return try answer.get()
    }
}
