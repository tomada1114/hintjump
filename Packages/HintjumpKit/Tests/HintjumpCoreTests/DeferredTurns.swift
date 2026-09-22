/// Stands in for the next main-run-loop turn: holds the work ``HintSession`` defers until
/// a test runs it, so the test can look at the state in between.
@MainActor
final class DeferredTurns {
    private(set) var pending: [@MainActor () -> Void] = []

    func schedule(_ work: @escaping @MainActor () -> Void) {
        pending.append(work)
    }

    /// Runs everything scheduled so far, in order.
    func runAll() {
        let work = pending
        pending = []
        for item in work {
            item()
        }
    }
}
