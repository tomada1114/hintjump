import Foundation
import HintjumpCore
import Testing

/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): a real
/// conforming implementation of the port whose answers are data handed in by the test,
/// and whose calls are recorded in plain values the test reads afterwards. This is the
/// port's first fake (`AccessibilityTreeReadingTests.swift`'s doc comment: "the first
/// decision over a `TreeSnapshot` brings its fake with it") — ``ManualAccessibilityWaker``
/// is that first decision. Internal rather than private because it is this port's one
/// fake: `WindowTargetCollectorTests` and `AppMenuTargetCollectorTests` read through it too.
final class FakeAccessibilityTreeReader: AccessibilityTreeReading, @unchecked Sendable {
    /// One `readTree` call's arguments.
    struct ReadRequest: Equatable {
        let pid: pid_t
        let scope: ReadScope
        let strategy: ReadStrategy
        let maxDepth: Int?
    }

    /// Safe without a lock: every test below drives it from the `@MainActor` suite, so
    /// the mutations and the reads happen on one actor.
    private(set) var readRequests: [ReadRequest] = []
    private(set) var enableManualAccessibilityCalls: [pid_t] = []

    private let readResults: [Result<TreeSnapshot, AccessibilityReadError>]
    private let enableError: AccessibilityReadError?

    /// How many times `readTree` was called, whether it answered or threw.
    var readTreeCallCount: Int {
        readRequests.count
    }

    /// Answers `readAnswers` in order, repeating the last one once they run out, and
    /// lets every `enableManualAccessibility(pid:)` call succeed.
    convenience init(readAnswers: [TreeSnapshot]) {
        self.init(readResults: readAnswers.map { .success($0) }, enableError: nil)
    }

    /// As ``init(readAnswers:)``, but every `enableManualAccessibility(pid:)` call throws
    /// `enableError` instead of succeeding.
    convenience init(readAnswers: [TreeSnapshot], enableError: AccessibilityReadError) {
        self.init(readResults: readAnswers.map { .success($0) }, enableError: enableError)
    }

    /// Every `readTree` call throws `readError` — a read that never answers.
    convenience init(readError: AccessibilityReadError) {
        self.init(readResults: [.failure(readError)], enableError: nil)
    }

    /// Answers or throws `readResults` in order, repeating the last one once they run
    /// out — a first read that fails and a second that answers, for a caller that falls
    /// back from one scope to another.
    convenience init(readResults: [Result<TreeSnapshot, AccessibilityReadError>]) {
        self.init(readResults: readResults, enableError: nil)
    }

    private init(
        readResults: [Result<TreeSnapshot, AccessibilityReadError>],
        enableError: AccessibilityReadError?,
    ) {
        self.readResults = readResults
        self.enableError = enableError
    }

    func readTree(
        pid: pid_t,
        scope: ReadScope,
        strategy: ReadStrategy,
        maxDepth: Int?,
    ) throws -> TreeSnapshot {
        let answerIndex = min(readRequests.count, readResults.count - 1)
        readRequests.append(
            ReadRequest(pid: pid, scope: scope, strategy: strategy, maxDepth: maxDepth),
        )
        return try readResults[answerIndex].get()
    }

    func enableManualAccessibility(pid: pid_t) throws {
        enableManualAccessibilityCalls.append(pid)
        if let enableError {
            throw enableError
        }
    }
}

/// Builds a snapshot around one root `AXWebArea`, with or without a child under it.
private func webAreaSnapshot(pid: pid_t, hasChild: Bool) -> TreeSnapshot {
    let webArea = ElementSnapshot(
        role: "AXWebArea",
        subrole: nil,
        title: nil,
        description: nil,
        frame: nil,
        isEnabled: true,
        actions: [],
        depth: 0,
        parentIndex: nil,
    )
    var elements = [webArea]
    if hasChild {
        elements.append(
            ElementSnapshot(
                role: "AXButton",
                subrole: nil,
                title: nil,
                description: nil,
                frame: nil,
                isEnabled: true,
                actions: ["AXPress"],
                depth: 1,
                parentIndex: 0,
            ),
        )
    }
    return TreeSnapshot(
        bundleIdentifier: "com.example.electron",
        pid: pid,
        scope: .focusedWindow,
        strategy: .batchedPruned,
        elements: elements,
        readDuration: .milliseconds(1),
    )
}

@Suite("EmptyWebAreaRule")
struct EmptyWebAreaRuleTests {
    @Test
    func `fires on a snapshot with an AXWebArea that has no children`() {
        #expect(EmptyWebAreaRule.matches(webAreaSnapshot(pid: 1, hasChild: false)))
    }

    @Test
    func `does not fire when the AXWebArea has a child`() {
        #expect(!EmptyWebAreaRule.matches(webAreaSnapshot(pid: 1, hasChild: true)))
    }

    @Test
    func `does not fire on a snapshot with no AXWebArea at all`() {
        let window = ElementSnapshot(
            role: "AXWindow",
            subrole: nil,
            title: nil,
            description: nil,
            frame: nil,
            isEnabled: true,
            actions: [],
            depth: 0,
            parentIndex: nil,
        )
        let snapshot = TreeSnapshot(
            bundleIdentifier: nil,
            pid: 1,
            scope: .focusedWindow,
            strategy: .batched,
            elements: [window],
            readDuration: .zero,
        )
        #expect(!EmptyWebAreaRule.matches(snapshot))
    }

    @Test
    func `does not fire on an empty iframe web area nested inside a non-empty one`() {
        // A page whose ad iframe `batchedPruned` left childless: the iframe is its own
        // nested AXWebArea, so it is empty while the page's web area is not.
        let snapshot = prunedSnapshot([
            element("AXWindow", depth: 0, parent: nil),
            element("AXWebArea", depth: 1, parent: 0),
            element("AXGroup", depth: 2, parent: 1),
            element("AXWebArea", depth: 3, parent: 2),
        ])
        #expect(!EmptyWebAreaRule.matches(snapshot))
    }

    @Test
    func `does not fire on an empty web area whose web area ancestor is several levels up`() {
        let snapshot = prunedSnapshot([
            element("AXWebArea", depth: 0, parent: nil),
            element("AXGroup", depth: 1, parent: 0),
            element("AXGroup", depth: 2, parent: 1),
            element("AXGroup", depth: 3, parent: 2),
            element("AXWebArea", depth: 4, parent: 3),
        ])
        #expect(!EmptyWebAreaRule.matches(snapshot))
    }

    @Test
    func `fires on an empty top-level web area under a window and a group`() {
        let snapshot = prunedSnapshot([
            element("AXWindow", depth: 0, parent: nil),
            element("AXGroup", depth: 1, parent: 0),
            element("AXWebArea", depth: 2, parent: 1),
        ])
        #expect(EmptyWebAreaRule.matches(snapshot))
    }

    @Test
    func `fires on an empty top-level web area beside a non-empty one`() {
        // Two sibling web areas, neither inside the other: the empty one is still a
        // top-level tree that never built its children.
        let snapshot = prunedSnapshot([
            element("AXWindow", depth: 0, parent: nil),
            element("AXWebArea", depth: 1, parent: 0),
            element("AXButton", depth: 2, parent: 1),
            element("AXWebArea", depth: 1, parent: 0),
        ])
        #expect(EmptyWebAreaRule.matches(snapshot))
    }
}

/// One element with only the fields ``EmptyWebAreaRule`` reads set.
private func element(_ role: String, depth: Int, parent: Int?) -> ElementSnapshot {
    ElementSnapshot(
        role: role,
        subrole: nil,
        title: nil,
        description: nil,
        frame: nil,
        isEnabled: true,
        actions: [],
        depth: depth,
        parentIndex: parent,
    )
}

/// Wraps `elements` in a `batchedPruned` snapshot, the strategy the product reads with.
private func prunedSnapshot(_ elements: [ElementSnapshot]) -> TreeSnapshot {
    TreeSnapshot(
        bundleIdentifier: "com.example.browser",
        pid: 1,
        scope: .focusedWindow,
        strategy: .batchedPruned,
        elements: elements,
        readDuration: .zero,
    )
}

@MainActor
@Suite("ManualAccessibilityWaker")
struct ManualAccessibilityWakerTests {
    @Test
    func `an empty AXWebArea triggers exactly one enable call and a second read`() {
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            webAreaSnapshot(pid: 42, hasChild: false),
            webAreaSnapshot(pid: 42, hasChild: true),
        ])
        let waker = ManualAccessibilityWaker(reader: reader)

        let result = try? waker.readTree(pid: 42, scope: .focusedWindow, strategy: .batchedPruned)

        #expect(result == webAreaSnapshot(pid: 42, hasChild: true))
        #expect(reader.enableManualAccessibilityCalls == [42])
        #expect(reader.readTreeCallCount == 2)
    }

    @Test
    func `a depth limit reaches the reader on the first read and on the read after waking`() {
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            webAreaSnapshot(pid: 42, hasChild: false),
            webAreaSnapshot(pid: 42, hasChild: true),
        ])
        let waker = ManualAccessibilityWaker(reader: reader)

        _ = try? waker.readTree(pid: 42, scope: .menuBar, strategy: .batched, maxDepth: 1)

        #expect(reader.readRequests == [
            .init(pid: 42, scope: .menuBar, strategy: .batched, maxDepth: 1),
            .init(pid: 42, scope: .menuBar, strategy: .batched, maxDepth: 1),
        ])
    }

    @Test
    func `without a depth limit the reader is asked for the whole tree`() {
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            webAreaSnapshot(pid: 42, hasChild: true),
        ])
        let waker = ManualAccessibilityWaker(reader: reader)

        _ = try? waker.readTree(pid: 42, scope: .focusedWindow, strategy: .batchedPruned)

        #expect(reader.readRequests == [
            .init(pid: 42, scope: .focusedWindow, strategy: .batchedPruned, maxDepth: nil),
        ])
    }

    @Test
    func `a tree with a populated AXWebArea never calls enable`() {
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            webAreaSnapshot(pid: 42, hasChild: true),
        ])
        let waker = ManualAccessibilityWaker(reader: reader)

        let result = try? waker.readTree(pid: 42, scope: .focusedWindow, strategy: .batchedPruned)

        #expect(result == webAreaSnapshot(pid: 42, hasChild: true))
        #expect(reader.enableManualAccessibilityCalls.isEmpty)
        #expect(reader.readTreeCallCount == 1)
    }

    @Test
    func `enable is never called twice for the same pid, even across repeated empty reads`() {
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            webAreaSnapshot(pid: 42, hasChild: false),
        ])
        let waker = ManualAccessibilityWaker(reader: reader)

        _ = try? waker.readTree(pid: 42, scope: .focusedWindow, strategy: .batchedPruned)
        _ = try? waker.readTree(pid: 42, scope: .focusedWindow, strategy: .batchedPruned)

        #expect(reader.enableManualAccessibilityCalls == [42])
        #expect(reader.readTreeCallCount == 3)
    }

    @Test
    func `each pid gets its own wake, remembered independently`() {
        let reader = FakeAccessibilityTreeReader(readAnswers: [
            webAreaSnapshot(pid: 1, hasChild: false),
        ])
        let waker = ManualAccessibilityWaker(reader: reader)

        _ = try? waker.readTree(pid: 1, scope: .focusedWindow, strategy: .batchedPruned)
        _ = try? waker.readTree(pid: 2, scope: .focusedWindow, strategy: .batchedPruned)

        #expect(reader.enableManualAccessibilityCalls == [1, 2])
    }

    @Test
    func `attributeUnsupported from enable is treated as needing no wake, not an error`() {
        let reader = FakeAccessibilityTreeReader(
            readAnswers: [webAreaSnapshot(pid: 42, hasChild: false)],
            enableError: .attributeUnsupported("AXManualAccessibility"),
        )
        let waker = ManualAccessibilityWaker(reader: reader)

        let result = try? waker.readTree(pid: 42, scope: .focusedWindow, strategy: .batchedPruned)

        #expect(result == webAreaSnapshot(pid: 42, hasChild: false))
        #expect(reader.enableManualAccessibilityCalls == [42])
        #expect(reader.readTreeCallCount == 1)

        // The pid is still remembered, so a second call never retries the enable.
        _ = try? waker.readTree(pid: 42, scope: .focusedWindow, strategy: .batchedPruned)
        #expect(reader.enableManualAccessibilityCalls == [42])
    }

    @Test
    func `a non-attributeUnsupported error from enable propagates`() {
        let reader = FakeAccessibilityTreeReader(
            readAnswers: [webAreaSnapshot(pid: 42, hasChild: false)],
            enableError: .notTrusted,
        )
        let waker = ManualAccessibilityWaker(reader: reader)

        #expect(throws: AccessibilityReadError.notTrusted) {
            try waker.readTree(pid: 42, scope: .focusedWindow, strategy: .batchedPruned)
        }
    }

    @Test
    func `a read error from the initial read propagates without touching enable`() {
        // With one element that has neither AXWebArea nor children, the rule never
        // fires, so no enable call happens regardless of the reader's answer count.
        let window = ElementSnapshot(
            role: "AXWindow",
            subrole: nil,
            title: nil,
            description: nil,
            frame: nil,
            isEnabled: true,
            actions: [],
            depth: 0,
            parentIndex: nil,
        )
        let snapshot = TreeSnapshot(
            bundleIdentifier: nil,
            pid: 7,
            scope: .application,
            strategy: .naive,
            elements: [window],
            readDuration: .zero,
        )
        let reader = FakeAccessibilityTreeReader(readAnswers: [snapshot])
        let waker = ManualAccessibilityWaker(reader: reader)

        let result = try? waker.readTree(pid: 7, scope: .application, strategy: .naive)

        #expect(result == snapshot)
        #expect(reader.enableManualAccessibilityCalls.isEmpty)
    }
}
