import CoreGraphics
import Foundation
import HintjumpCore
import Testing

extension HintSessionTests {
    /// A session with ``StatusItemTargetCollector`` behind `.statusIcons` and a window
    /// collector behind `.clickInWindow`, with `app` frontmost.
    @MainActor
    struct StatusIconsFixture {
        let listing = FakeStatusItemListing(answering: StatusIcons.scan)
        let windowCollector = FakeHintTargetCollector(
            answering: HintSessionTests.targetSet(count: 1),
        )
        let presenter = FakeHintOverlayPresenter(screen: HintSessionTests.screen)
        let clicker = FakeClickPerformer()
        let turns = DeferredTurns()
        let session: HintSession

        /// `app` frontmost, with the default configuration.
        init(app: FrontmostApp?) {
            self.init(app: app, configuration: .default)
        }

        init(app: FrontmostApp?, configuration: HintjumpConfig) {
            let deferred = turns
            session = HintSession(
                frontmostApp: FakeFrontmostAppProvider(answering: [app]),
                collectors: [
                    .clickInWindow: windowCollector,
                    .statusIcons: StatusItemTargetCollector(listing: listing),
                ],
                presenter: presenter,
                clicker: clicker,
                configuration: { configuration },
                deferToNextTurn: { deferred.schedule($0) },
            )
        }
    }

    /// The status-items entry point: a collector that scans the menu bar instead of
    /// reading the frontmost app, run through the same session as the window ones.
    @MainActor
    @Suite("status icons")
    struct StatusIcons {
        static let bar = CGRect(x: 0, y: 0, width: 1_440, height: 24)
        /// Two items, listed right one first: the session must label them left to right.
        static let scan = StatusItemScan(
            barFrame: bar,
            visibleSegments: [bar],
            windows: [
                StatusItemWindow(pid: 300, frame: CGRect(x: 1_300, y: 0, width: 40, height: 24)),
                StatusItemWindow(pid: 200, frame: CGRect(x: 1_200, y: 0, width: 30, height: 24)),
            ],
        )
        static let hintjump = FrontmostApp(
            name: "Hintjump",
            bundleIdentifier: AppLog.subsystem,
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
        )

        @Test
        func `the press labels the status items left to right, filled, on the bar's screen`() {
            let fixture = StatusIconsFixture(app: HintSessionTests.app)

            fixture.session.trigger(.statusIcons)

            #expect(fixture.session.overlay?.entryPoint == .statusIcons)
            #expect(fixture.session.overlay?.style == .filled)
            #expect(fixture.session.overlay?.chip == nil)
            #expect(fixture.session.overlay?.hints.map(\.label) == ["a", "s"])
            #expect(fixture.presenter.screenQueries == [CGPoint(x: 720, y: 12)])
            #expect(fixture.presenter.shows.map(\.canvas) == [HintSessionTests.screen])
        }

        @Test
        func `typing an item's label left-clicks its center on the next turn`() {
            let fixture = StatusIconsFixture(app: HintSessionTests.app)
            fixture.session.trigger(.statusIcons)

            fixture.presenter.type("s")
            #expect(fixture.clicker.clicks.isEmpty)
            fixture.turns.runAll()

            #expect(fixture.session.overlay == nil)
            #expect(fixture.presenter.hideCount == 1)
            let click = FakeClickPerformer.Click(point: CGPoint(x: 1_320, y: 12), button: .left)
            #expect(fixture.clicker.clicks == [click])
        }

        @Test
        func `with Hintjump itself frontmost the status items are still labeled`() {
            let fixture = StatusIconsFixture(app: Self.hintjump)

            fixture.session.trigger(.statusIcons)

            #expect(fixture.listing.scanCount == 1)
            #expect(fixture.session.overlay?.hints.count == 2)
        }

        @Test
        func `with Hintjump itself frontmost a window trigger still reads nothing`() {
            let fixture = StatusIconsFixture(app: Self.hintjump)

            fixture.session.trigger(.clickInWindow)

            #expect(fixture.windowCollector.readsFrontmostApp)
            #expect(fixture.windowCollector.collectedApps.isEmpty)
            #expect(fixture.session.overlay == nil)
        }

        @Test(arguments: [nil, FrontmostApp(name: "Helper", bundleIdentifier: nil)])
        func `no frontmost app, or one with no pid, scans nothing`(app: FrontmostApp?) {
            let fixture = StatusIconsFixture(app: app)

            fixture.session.trigger(.statusIcons)

            #expect(fixture.listing.scanCount == 0)
            #expect(fixture.session.overlay == nil)
        }

        @Test
        func `a disabled app frontmost scans nothing, for the moment before the switch lands`() {
            var config = HintjumpConfig.default
            config.disabledApps = ["com.apple.finder"]
            let fixture = StatusIconsFixture(app: HintSessionTests.app, configuration: config)

            fixture.session.trigger(.statusIcons)

            #expect(fixture.listing.scanCount == 0)
            #expect(fixture.session.overlay == nil)
        }

        @Test
        func `a status-items press replaces window hints, and a second press closes its own`() {
            let fixture = StatusIconsFixture(app: HintSessionTests.app)
            fixture.session.trigger(.clickInWindow)

            fixture.session.trigger(.statusIcons)
            #expect(fixture.session.overlay?.entryPoint == .statusIcons)

            fixture.session.trigger(.statusIcons)
            #expect(fixture.session.overlay == nil)
            #expect(fixture.listing.scanCount == 1)
            #expect(fixture.presenter.hideCount == 2)
        }
    }
}
