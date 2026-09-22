import AppKit
import HintjumpCore
import HintjumpPlatform
import Testing

/// The adapter against the real Accessibility API, read from the one application every
/// Mac is running: Finder.
///
/// What a Core test with a fake cannot ask — does `AXUIElementCopyAttributeValue`
/// really answer what the translation assumes, and does the walk really come back in
/// pre-order? Everything downstream of the snapshot (which element is worth a hint,
/// what a read costs the product) stays a Core test, where the coverage floor sees it
/// (`.claude/rules/testing.md` › Where a Test Goes).
///
/// Unlike `WorkspaceFrontmostAppProviderTests` this one needs a TCC grant: the
/// Accessibility permission, held by the application that launched the run, so
/// `just test-local` from a terminal that has it. A missing grant makes the read fail
/// rather than answer, which is why the read is unwrapped through
/// `LocalMachineTests.require(_:requires:grant:)` — the failure then names the grant to
/// give instead of reading as a broken adapter.
@Suite("AXUIElementTreeReader against the real Accessibility API", .requiresLocalMachine)
@MainActor
struct AXUIElementTreeReaderTests {
    static let finderBundleIdentifier = "com.apple.finder"

    @Test
    func `reads Finder's application tree and finds something pressable`() throws {
        let pid = try Self.finderProcessIdentifier()
        let tree = try Self.readFinder(pid: pid, scope: .application, strategy: .naive)

        #expect(tree.pid == pid)
        #expect(tree.bundleIdentifier == Self.finderBundleIdentifier)
        #expect(tree.scope == .application)
        #expect(tree.strategy == .naive)
        #expect(tree.readDuration > .zero)
        #expect(!tree.elements.isEmpty)
        #expect(tree.elements[0].depth == 0)
        #expect(tree.elements[0].parentIndex == nil)

        // The point of the whole port: an element the product could label. Finder's menu
        // bar alone guarantees several, with no window open.
        #expect(
            tree.elements.contains { $0.actions.contains("AXPress") },
            "none of Finder's \(tree.elements.count) elements reports an AXPress action",
        )
    }

    @Test
    func `flattens the menu bar in pre-order`() throws {
        let pid = try Self.finderProcessIdentifier()
        let tree = try Self.readFinder(pid: pid, scope: .menuBar, strategy: .naive)

        #expect(tree.elements.count > 1, "Finder's menu bar should hold more than its root")
        for (index, element) in tree.elements.enumerated() {
            guard let parentIndex = element.parentIndex else {
                #expect(index == 0, "element #\(index) has no parent but is not the root")
                #expect(element.depth == 0)
                continue
            }
            // A parent always precedes its children, which is what lets a caller read the
            // flat list as a tree without holding an index of its own.
            #expect(parentIndex < index, "element #\(index) claims a parent at \(parentIndex)")
            #expect(element.depth == tree.elements[parentIndex].depth + 1)
        }
    }

    @Test
    func `reads the same menu bar batched as one attribute at a time`() throws {
        let pid = try Self.finderProcessIdentifier()
        let naive = try Self.readFinder(pid: pid, scope: .menuBar, strategy: .naive)
        let batched = try Self.readFinder(pid: pid, scope: .menuBar, strategy: .batched)

        // `.batched` is allowed to be faster, never different: the strategies are a
        // translation choice, so the values they produce have to agree.
        #expect(naive.elements.count == batched.elements.count)
        #expect(naive.elements.map(\.role) == batched.elements.map(\.role))
        #expect(naive.elements.map(\.depth) == batched.elements.map(\.depth))
    }

    @Test
    func `prunes the same menu bar batched as one attribute at a time`() throws {
        let pid = try Self.finderProcessIdentifier()
        let pruned = try Self.readFinder(pid: pid, scope: .menuBar, strategy: .pruned)
        let batchedPruned = try Self.readFinder(pid: pid, scope: .menuBar, strategy: .batchedPruned)

        // The visible subsets ride in the batched call on one path and are asked one at a
        // time on the other; which children the walk descends must not depend on that.
        #expect(pruned.elements.count == batchedPruned.elements.count)
        #expect(pruned.elements.map(\.role) == batchedPruned.elements.map(\.role))
        #expect(pruned.elements.map(\.depth) == batchedPruned.elements.map(\.depth))
    }
}

/// Getting at Finder, and turning a missing grant into the instruction to give it.
extension AXUIElementTreeReaderTests {
    static func finderProcessIdentifier() throws -> pid_t {
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: finderBundleIdentifier,
        )
        let finder = try LocalMachineTests.require(
            running.first,
            requires: """
            a logged-in GUI session with Finder running — it is launched by the session \
            itself, so a headless runner is what answers nothing here
            """,
            grant: false,
        )
        return finder.processIdentifier
    }

    /// Reads Finder, turning a missing grant into the instruction to give it.
    ///
    /// Only ``HintjumpCore/AccessibilityReadError/notTrusted`` is turned into `nil` for
    /// `LocalMachineTests.require`: that one means "give your terminal a permission",
    /// not "the adapter is broken". Every other error propagates as itself, so a real
    /// translation failure is reported as what it is.
    static func readFinder(
        pid: pid_t,
        scope: ReadScope,
        strategy: ReadStrategy,
    ) throws -> TreeSnapshot {
        let reader = AXUIElementTreeReader()
        let tree: TreeSnapshot?
        do {
            tree = try reader.readTree(pid: pid, scope: scope, strategy: strategy)
        } catch AccessibilityReadError.notTrusted {
            tree = nil
        }
        return try LocalMachineTests.require(
            tree,
            requires: "the Accessibility permission",
            grant: true,
        )
    }
}
