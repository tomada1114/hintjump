import HintjumpCore

/// The fake every Core test of ``StatusItemListing`` uses: answers every `scan` with the
/// one scan it was built with, and counts the calls (`.claude/rules/testing.md` › Fakes,
/// not mocks). `@MainActor`, like the port's method.
@MainActor
final class FakeStatusItemListing: StatusItemListing {
    /// How many times `scan` was called.
    private(set) var scanCount = 0
    private let answer: StatusItemScan?

    /// Answers every call with `scan` — `nil` stands for "no screen".
    init(answering scan: StatusItemScan?) {
        answer = scan
    }

    func scan() -> StatusItemScan? {
        scanCount += 1
        return answer
    }
}
