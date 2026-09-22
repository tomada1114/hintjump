import CoreGraphics
import Foundation
import HintjumpCore
import Testing

/// Turning a scan of the menu bar's status-item windows into hint targets, against
/// `FakeStatusItemListing`.
@MainActor
@Suite("StatusItemTargetCollector")
struct StatusItemTargetCollectorTests {
    static let app = FrontmostApp(
        name: "Finder",
        bundleIdentifier: "com.apple.finder",
        processIdentifier: 4_242,
    )
    /// A 1440 pt wide, 24 pt tall bar with a camera housing between x = 640 and x = 800.
    static let bar = CGRect(x: 0, y: 0, width: 1_440, height: 24)
    static let leftOfNotch = CGRect(x: 0, y: 0, width: 640, height: 24)
    static let rightOfNotch = CGRect(x: 800, y: 0, width: 640, height: 24)

    /// A status-item window of `width` at `minX`, as tall as the bar.
    private static func item(
        _ minX: CGFloat,
        width: CGFloat = 30,
        pid: pid_t = 99,
    ) -> StatusItemWindow {
        StatusItemWindow(pid: pid, frame: CGRect(x: minX, y: 0, width: width, height: 24))
    }

    private static func scan(
        _ windows: [StatusItemWindow],
        segments: [CGRect] = [leftOfNotch, rightOfNotch],
    ) -> StatusItemScan {
        StatusItemScan(barFrame: bar, visibleSegments: segments, windows: windows)
    }

    private static func collect(
        _ scan: StatusItemScan?,
        from app: FrontmostApp = app,
    ) -> TargetSet {
        StatusItemTargetCollector(listing: FakeStatusItemListing(answering: scan))
            .collect(from: app)
    }

    @Test
    func `orders the items left to right and clicks each at its center`() {
        let set = Self.collect(Self.scan([
            Self.item(1_200),
            Self.item(900, width: 40),
            Self.item(1_000),
        ]))

        #expect(set.targets.map(\.frame.minX) == [900, 1_000, 1_200])
        #expect(set.targets.map(\.clickPoint) == [
            CGPoint(x: 920, y: 12),
            CGPoint(x: 1_015, y: 12),
            CGPoint(x: 1_215, y: 12),
        ])
        #expect(set.targets.allSatisfy { $0.role == nil })
    }

    @Test
    func `the set is rooted at the bar and names the frontmost app for the log`() {
        let set = Self.collect(Self.scan([Self.item(1_000)]))

        #expect(set.rootFrame == Self.bar)
        #expect(set.pid == 4_242)
        #expect(set.bundleIdentifier == "com.apple.finder")
        #expect(set.readDuration >= .zero)
    }

    @Test(arguments: [
        // Below the bar: a status-level window that is not a status item.
        CGRect(x: 1_000, y: 100, width: 30, height: 24),
        // Hanging off the bottom of the bar.
        CGRect(x: 1_000, y: 10, width: 30, height: 24),
        // Slivers: 2 pt wide, 2 pt tall.
        CGRect(x: 1_100, y: 0, width: 2, height: 24),
        CGRect(x: 1_100, y: 0, width: 30, height: 2),
        // Behind the camera housing, and straddling its right edge.
        CGRect(x: 700, y: 0, width: 30, height: 24),
        CGRect(x: 790, y: 0, width: 30, height: 24),
        // Pushed off the left of the screen.
        CGRect(x: -30, y: 0, width: 30, height: 24),
    ])
    func `a window not wholly inside one visible segment, or a sliver, gets no hint`(frame: CGRect) {
        let set = Self.collect(Self.scan([
            StatusItemWindow(pid: 99, frame: frame),
            Self.item(1_000),
        ]))

        #expect(set.targets.map(\.frame) == [Self.item(1_000).frame])
    }

    @Test
    func `a window just over 2 pt each way is kept`() {
        let frame = CGRect(x: 1_300, y: 0, width: 3, height: 3)

        let set = Self.collect(Self.scan([StatusItemWindow(pid: 99, frame: frame)]))

        #expect(set.targets.map(\.frame) == [frame])
    }

    @Test
    func `an item reaching 2 pt past the screen edge, like macOS 26's clock, is kept`() {
        let clock = CGRect(x: 1_300, y: 0, width: 142, height: 24)

        let set = Self.collect(Self.scan([StatusItemWindow(pid: 99, frame: clock)]))

        #expect(set.targets.map(\.frame) == [clock])
    }

    @Test
    func `an item filling its segment exactly is kept`() {
        let set = Self.collect(Self.scan([StatusItemWindow(pid: 99, frame: Self.rightOfNotch)]))

        #expect(set.targets.map(\.frame) == [Self.rightOfNotch])
    }

    @Test
    func `a segment reported outside the bar hints nothing in it`() {
        let stray = CGRect(x: 0, y: 100, width: 200, height: 24)
        let scan = StatusItemScan(
            barFrame: Self.bar,
            visibleSegments: [stray],
            windows: [StatusItemWindow(pid: 99, frame: stray.insetBy(dx: 10, dy: 0))],
        )

        #expect(Self.collect(scan).targets.isEmpty)
    }

    @Test
    func `a frame reported twice gets one hint`() {
        let set = Self.collect(Self.scan([
            Self.item(1_000, pid: 1),
            Self.item(1_000, pid: 2),
            Self.item(1_100),
        ]))

        #expect(set.targets.map(\.frame.minX) == [1_000, 1_100])
    }

    @Test
    func `without a notch the whole bar is one segment`() {
        let set = Self.collect(Self.scan([Self.item(700), Self.item(100)], segments: [Self.bar]))

        #expect(set.targets.map(\.frame.minX) == [100, 700])
    }

    @Test
    func `no screen yields an empty set rooted nowhere`() {
        let set = Self.collect(nil)

        #expect(set.targets.isEmpty)
        #expect(set.rootFrame == .zero)
        #expect(set.pid == 4_242)
    }

    @Test
    func `a frontmost app with no process identifier is logged as pid 0, and still collected`() {
        let set = Self.collect(Self.scan([Self.item(1_000)]), from: FrontmostApp(name: "Helper"))

        #expect(set.pid == 0)
        #expect(set.bundleIdentifier == nil)
        #expect(set.targets.count == 1)
    }

    @Test
    func `scans once per press, and does not read the frontmost app's tree`() {
        let listing = FakeStatusItemListing(answering: Self.scan([Self.item(1_000)]))
        let collector = StatusItemTargetCollector(listing: listing)

        _ = collector.collect(from: Self.app)
        _ = collector.collect(from: Self.app)

        #expect(listing.scanCount == 2)
        #expect(!collector.readsFrontmostApp)
    }
}
