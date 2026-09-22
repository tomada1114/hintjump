import AppKit
import HintjumpCore
import HintjumpPlatform
import Testing

/// `WindowListStatusItems` against the real window server and screen.
///
/// What a Core test with `FakeStatusItemListing` cannot show: that the status items
/// really are on-screen windows at `CGWindowLevelForKey(.statusWindow)`, that their
/// bounds really arrive in the bar's top-left-origin space, and that the bar is where the
/// adapter says. It needs no TCC grant — layer, bounds, and owner pid are readable
/// without Screen Recording — only a logged-in GUI session with a menu bar. The test
/// process has no status item of its own, but Control Center's clock is always one.
@Suite("WindowListStatusItems against the real window server", .requiresLocalMachine)
@MainActor
struct WindowListStatusItemsTests {
    @Test
    func `finds the menu bar at the top of the primary screen and a status item inside it`() throws {
        let scan = try LocalMachineTests.require(
            WindowListStatusItems().scan(),
            requires: "a logged-in GUI session with a screen — the window list needs no permission",
            grant: false,
        )

        #expect(scan.barFrame.minY == 0)
        #expect(scan.barFrame.height > 0)
        #expect(scan.barFrame.width == NSScreen.screens.first?.frame.width)
        #expect(!scan.visibleSegments.isEmpty)
        #expect(scan.visibleSegments.allSatisfy { scan.barFrame.contains($0) })
        let inBar = scan.windows.filter { scan.barFrame.contains($0.frame) }
        #expect(
            !inBar.isEmpty,
            "none of the \(scan.windows.count) status-level windows lies inside \(scan.barFrame)",
        )
    }

    @Test
    func `the collector over the real scan hints at least one item, left to right`() {
        let app = FrontmostApp(name: "Test", bundleIdentifier: nil, processIdentifier: 1)

        let set = StatusItemTargetCollector(listing: WindowListStatusItems()).collect(from: app)

        #expect(!set.targets.isEmpty)
        let minXs = set.targets.map(\.frame.minX)
        #expect(minXs == minXs.sorted())
        #expect(set.targets.allSatisfy { set.rootFrame.contains($0.clickPoint) })
    }
}
