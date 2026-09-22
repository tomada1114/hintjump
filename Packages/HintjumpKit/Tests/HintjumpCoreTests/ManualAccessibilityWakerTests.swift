import Foundation
import HintjumpCore
import Testing

/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): a real
/// conforming implementation of the port whose answers are data handed in by the test,
/// and whose calls are recorded in plain values the test reads afterwards. This is the
/// port's first fake (`AccessibilityTreeReadingTests.swift`'s doc comment: "the first
/// decision over a `TreeSnapshot` brings its fake with it") — ``ManualAccessibilityWaker``
/// is that first decision.
private final class FakeAccessibilityTreeReader: AccessibilityTreeReading, @unchecked Sendable {
    /// Safe without a lock: every test below drives it from the `@MainActor` suite, so
    /// the mutations and the reads happen on one actor.
    private(set) var readTreeCallCount = 0
    private(set) var enableManualAccessibilityCalls: [pid_t] = []

    private let readAnswers: [TreeSnapshot]
    private let enableError: AccessibilityReadError?

    /// `readAnswers` are returned in order, repeating the last one once they run out.
    /// `enableError`, when given, is thrown from every
    /// `enableManualAccessibility(pid:)` call instead of succeeding.
    init(readAnswers: [TreeSnapshot], enableError: AccessibilityReadError? = nil) {
        self.readAnswers = readAnswers
        self.enableError = enableError
    }

    func readTree(
        pid _: pid_t,
        scope _: ReadScope,
        strategy _: ReadStrategy,
    ) -> TreeSnapshot {
        defer { readTreeCallCount += 1 }
        return readAnswers[min(readTreeCallCount, readAnswers.count - 1)]
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
