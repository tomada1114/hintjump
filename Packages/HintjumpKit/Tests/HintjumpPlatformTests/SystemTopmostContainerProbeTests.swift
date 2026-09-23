import AppKit
import HintjumpCore
import HintjumpPlatform
import Testing

/// `SystemTopmostContainerProbe` and the `.popUpMenu` read against the real Accessibility
/// API and window server.
///
/// What a Core test with `FakeTopmostContainerProbe` cannot show: that the window list
/// really lists only windows above the normal layer, that the pop-up-menu flag really
/// marks `kCGPopUpMenuWindowLevel`, that the menu bar strip is the one the status items
/// sit in, and that the system-wide focused application answers. Quiet: every test only
/// reads, and none opens, clicks, or focuses anything. The one test that needs an open
/// context menu skips with a notice unless a person has one open in the frontmost app —
/// the tests never open one themselves.
@Suite("SystemTopmostContainerProbe against the real OS", .requiresLocalMachine)
@MainActor
struct SystemTopmostContainerProbeTests {
    static let normalLayer = Int(CGWindowLevelForKey(.normalWindow))
    static let popUpMenuLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))
    static let samples = 20

    /// Whether the frontmost application owns an on-screen pop-up-menu-level window now —
    /// a context menu a person opened.
    static func frontmostOwnsPopUpMenuWindow() async -> Bool {
        await MainActor.run {
            guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
                return false
            }
            return SystemTopmostContainerProbe().signals().raisedWindows.contains { window in
                window.isPopUpMenuLevel && window.pid == pid
            }
        }
    }

    /// Reads `scope` of `pid`, turning a missing grant into the instruction to give it.
    static func read(pid: pid_t, scope: ReadScope) throws -> TreeSnapshot {
        let tree: TreeSnapshot?
        do {
            tree = try AXUIElementTreeReader().readTree(
                pid: pid,
                scope: scope,
                strategy: .batchedPruned,
            )
        } catch AccessibilityReadError.notTrusted {
            tree = nil
        }
        return try LocalMachineTests.require(
            tree,
            requires: "the Accessibility permission",
            grant: true,
        )
    }

    @Test
    func `lists raised windows only, flags the pop-up-menu level, and finds the bar`() throws {
        let signals = SystemTopmostContainerProbe().signals()
        let bar = try LocalMachineTests.require(
            WindowListStatusItems().scan()?.barFrame,
            requires: "a logged-in GUI session with a screen — the window list needs no permission",
            grant: false,
        )

        #expect(signals.menuBarHeight == bar.height)
        #expect(!signals.raisedWindows.isEmpty)
        for window in signals.raisedWindows {
            #expect(window.layer > Self.normalLayer)
            #expect(window.isPopUpMenuLevel == (window.layer == Self.popUpMenuLayer))
        }
        // Control Center's clock is always a status item, wholly inside the strip.
        #expect(
            signals.raisedWindows.contains { $0.frame.maxY <= signals.menuBarHeight },
            "no raised window lies inside the \(signals.menuBarHeight) pt menu bar strip",
        )
    }

    @Test
    func `the system-wide focused application answers a running process`() throws {
        // #9 saw the first read fail with kAXErrorCannotComplete while an Electron app was
        // frontmost and every later one answer, so a second sample is allowed.
        let probe = SystemTopmostContainerProbe()
        let focused = try LocalMachineTests.require(
            probe.signals().focusedApplicationPID ?? probe.signals().focusedApplicationPID,
            requires: "the Accessibility permission",
            grant: true,
        )

        #expect(NSRunningApplication(processIdentifier: focused) != nil)
    }

    @Test
    func `reading the signals costs no more than a few milliseconds`() {
        let probe = SystemTopmostContainerProbe()
        let clock = ContinuousClock()
        var durations: [Duration] = []
        for _ in 0 ..< Self.samples {
            let start = clock.now
            _ = probe.signals()
            durations.append(start.duration(to: clock.now))
        }
        let sorted = durations.sorted()
        let median = sorted[sorted.count / 2]
        let slowest = sorted[sorted.count - 1]
        print(
            "SystemTopmostContainerProbe.signals() p50=\(median) max=\(slowest) over \(Self.samples)",
        )

        // The read alone gets 200 ms of the 300 ms budget; the probe is on top of it.
        #expect(median < .milliseconds(20), "p50 \(median)")
    }

    @Test
    func `a process with no pop-up-menu-level window has no pop-up menu to read`() throws {
        let own = ProcessInfo.processInfo.processIdentifier

        let error = #expect(throws: AccessibilityReadError.self) {
            try AXUIElementTreeReader().readTree(
                pid: own,
                scope: .popUpMenu,
                strategy: .batchedPruned,
            )
        }

        if error == .notTrusted {
            _ = try LocalMachineTests.require(
                String?.none,
                requires: "the Accessibility permission",
                grant: true,
            )
        }
        // This test process owns no window at all, so the hit test is never made.
        #expect(error == .attributeUnsupported("AXMenu"))
    }

    @Test(
        .enabled(
            "needs a context menu open in the frontmost app, which only a person can open — skipped",
        ) {
            await frontmostOwnsPopUpMenuWindow()
        },
    )
    func `an open context menu is read from its pop-up-menu-level window as an AXMenu`() throws {
        let pid = try #require(NSWorkspace.shared.frontmostApplication?.processIdentifier)

        let tree = try Self.read(pid: pid, scope: .popUpMenu)

        #expect(tree.elements.first?.role == "AXMenu")
        #expect(tree.elements.contains { $0.role == "AXMenuItem" })
        let menuItems = TargetRanker().rank(tree.elements)
            .filter { $0.element.role == "AXMenuItem" }
        #expect(!menuItems.isEmpty, "the ranker admitted none of the menu's items")
    }
}
