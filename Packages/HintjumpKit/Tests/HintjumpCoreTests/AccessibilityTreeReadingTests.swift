import Foundation
import HintjumpCore
import Testing

/// The value types the accessibility reader port answers with.
///
/// There is no Core consumer of the port yet, so no fake: the first decision over a
/// `TreeSnapshot` brings its fake with it (`.claude/rules/testing.md` › Fakes, not mocks).
/// What is pinned here is the vocabulary the verifications and the adapter share.
@Suite("Accessibility tree reading port")
struct AccessibilityTreeReadingTests {
    @Test(arguments: [
        (ReadStrategy.naive, false, false),
        (.batched, true, false),
        (.pruned, false, true),
        (.batchedPruned, true, true),
    ])
    func `strategy flags name the two techniques it combines`(
        strategy: ReadStrategy,
        batched: Bool,
        pruned: Bool,
    ) {
        #expect(strategy.readsAttributesInOneCall == batched)
        #expect(strategy.prunesInvisibleSubtrees == pruned)
    }

    @Test
    func `every scope and strategy has a stable name a command line can use`() {
        #expect(ReadScope.allCases.map(\.rawValue) == ["application", "focusedWindow", "menuBar"])
        #expect(
            ReadStrategy.allCases.map(\.rawValue) == [
                "batched",
                "batchedPruned",
                "naive",
                "pruned",
            ],
        )
    }

    @Test
    func `a snapshot keeps every field it was given`() {
        let root = ElementSnapshot(
            role: "AXWindow",
            subrole: "AXStandardWindow",
            title: "Untitled",
            description: nil,
            frame: CGRect(x: 1, y: 2, width: 3, height: 4),
            isEnabled: true,
            actions: ["AXRaise"],
            depth: 0,
            parentIndex: nil,
        )
        let button = ElementSnapshot(
            role: "AXButton",
            subrole: nil,
            title: nil,
            description: "Close",
            frame: nil,
            isEnabled: false,
            actions: ["AXPress"],
            depth: 1,
            parentIndex: 0,
        )
        let tree = TreeSnapshot(
            bundleIdentifier: "com.example.app",
            pid: 42,
            scope: .focusedWindow,
            strategy: .batched,
            elements: [root, button],
            readDuration: .milliseconds(7),
        )

        #expect(tree.elements[0].frame == CGRect(x: 1, y: 2, width: 3, height: 4))
        #expect(tree.elements[0].parentIndex == nil)
        #expect(tree.elements[1].parentIndex == 0)
        #expect(tree.elements[1].actions == ["AXPress"])
        #expect(tree.elements[1].isEnabled == false)
        #expect(tree.pid == 42)
        #expect(tree.bundleIdentifier == "com.example.app")
        #expect(tree.scope == .focusedWindow)
        #expect(tree.strategy == .batched)
        #expect(tree.readDuration == .milliseconds(7))
        #expect(tree.elements[0] != tree.elements[1])
    }

    @Test
    func `errors compare by case and payload`() {
        #expect(AccessibilityReadError.noSuchProcess(1) == .noSuchProcess(1))
        #expect(AccessibilityReadError.noSuchProcess(1) != .noSuchProcess(2))
        #expect(AccessibilityReadError.attributeUnsupported("AXFocusedWindow") != .notTrusted)
        #expect(AccessibilityReadError.failed(code: -1) == .failed(code: -1))
    }
}
