import CoreGraphics
import Foundation
import HintjumpCore
import Testing

extension HintSessionTests {
    /// From a trigger press to hints on screen — and every reason a press shows nothing.
    @MainActor
    @Suite("trigger")
    struct Trigger {
        @Test
        func `a left-click trigger shows filled hints on the screen holding the window`() throws {
            let fixture = Fixture(targetCount: 3)

            fixture.session.trigger(.clickInWindow)

            #expect(fixture.session.overlay == HintOverlayState(
                entryPoint: .clickInWindow,
                style: .filled,
                canvas: HintSessionTests.screen,
                hints: HintSessionTests.hints(count: 3),
                chip: nil,
            ))
            #expect(fixture.presenter.screenQueries == [CGPoint(x: 500, y: 400)])
            #expect(fixture.presenter.shows.map(\.canvas) == [HintSessionTests.screen])
            #expect(fixture.collector.collectedApps == [HintSessionTests.app])
            #expect(try #require(fixture.session.overlay?.hints.first).label == "a")
        }

        @Test
        func `a right-click trigger shows outlined hints and the Right click chip`() {
            let fixture = Fixture(targetCount: 2)

            fixture.session.trigger(.rightClickInWindow)

            #expect(fixture.session.overlay?.style == .outlined)
            #expect(fixture.session.overlay?.chip == HintLayout.chip(
                for: HintSessionTests.rootFrame,
                in: HintSessionTests.screen,
            ))
        }

        @Test
        func `with no screen holding the window, the window itself is the canvas`() {
            let fixture = Fixture(
                app: HintSessionTests.app,
                collector: FakeHintTargetCollector(answering: HintSessionTests.targetSet(count: 1)),
                screen: nil,
            )

            fixture.session.trigger(.clickInWindow)

            #expect(fixture.session.overlay?.canvas == HintSessionTests.rootFrame)
            #expect(fixture.presenter.shows.map(\.canvas) == [HintSessionTests.rootFrame])
        }

        @Test
        func `targets past the label supply are left unhinted`() {
            let capacity = LabelAssigner()
                .capacity(characters: HintjumpConfig.default.hintCharacters)
            let fixture = Fixture(targetCount: capacity + 24)

            fixture.session.trigger(.clickInWindow)

            #expect(fixture.session.overlay?.hints.count == capacity)
        }

        @Test
        func `pressing the same trigger again closes the hints and shows nothing new`() {
            let fixture = Fixture(targetCount: 3)

            fixture.session.trigger(.clickInWindow)
            fixture.session.trigger(.clickInWindow)

            #expect(fixture.session.overlay == nil)
            #expect(fixture.presenter.hideCount == 1)
            #expect(fixture.presenter.shows.count == 1)
            #expect(fixture.collector.collectedApps.count == 1)
        }

        @Test
        func `a third press of the same trigger shows the hints again`() {
            let fixture = Fixture(targetCount: 3)

            fixture.session.trigger(.clickInWindow)
            fixture.session.trigger(.clickInWindow)
            fixture.session.trigger(.clickInWindow)

            #expect(fixture.session.overlay?.entryPoint == .clickInWindow)
            #expect(fixture.presenter.shows.count == 2)
        }

        @Test
        func `a different trigger replaces the hints`() {
            let fixture = Fixture(targetCount: 3)

            fixture.session.trigger(.clickInWindow)
            fixture.session.trigger(.rightClickInWindow)

            #expect(fixture.session.overlay?.entryPoint == .rightClickInWindow)
            #expect(fixture.session.overlay?.style == .outlined)
            #expect(fixture.presenter.hideCount == 1)
            #expect(fixture.presenter.shows.count == 2)
        }

        @Test(arguments: [
            AccessibilityReadError.notTrusted,
            .attributeUnsupported("AXFocusedWindow"),
            .failed(code: -25_204),
            .noSuchProcess(HintSessionTests.pid),
        ])
        func `a read that fails shows nothing`(error: AccessibilityReadError) {
            let fixture = Fixture(
                app: HintSessionTests.app,
                collector: FakeHintTargetCollector(throwing: error),
                screen: HintSessionTests.screen,
            )

            fixture.session.trigger(.clickInWindow)

            #expect(fixture.session.overlay == nil)
            #expect(fixture.presenter.shows.isEmpty)
            #expect(fixture.collector.collectedApps == [HintSessionTests.app])
        }

        @Test(arguments: [
            nil,
            FrontmostApp(name: "Helper", bundleIdentifier: nil),
            FrontmostApp(
                name: "Hintjump",
                bundleIdentifier: AppLog.subsystem,
                processIdentifier: ProcessInfo.processInfo.processIdentifier,
            ),
        ])
        func `no frontmost app, no pid, or this process frontmost reads nothing`(
            app: FrontmostApp?,
        ) {
            let fixture = Fixture(
                app: app,
                collector: FakeHintTargetCollector(answering: HintSessionTests.targetSet(count: 3)),
                screen: HintSessionTests.screen,
            )

            fixture.session.trigger(.clickInWindow)

            #expect(fixture.session.overlay == nil)
            #expect(fixture.collector.collectedApps.isEmpty)
            #expect(fixture.presenter.shows.isEmpty)
        }

        @Test(arguments: [EntryPoint.appMenus, .statusIcons])
        func `an entry point with no collector yet shows nothing`(entryPoint: EntryPoint) {
            let fixture = Fixture(targetCount: 3)

            fixture.session.trigger(entryPoint)

            #expect(fixture.session.overlay == nil)
            #expect(fixture.presenter.shows.isEmpty)
            #expect(fixture.collector.collectedApps.isEmpty)
        }

        @Test
        func `a window with no targets shows nothing`() {
            let fixture = Fixture(targetCount: 0)

            fixture.session.trigger(.clickInWindow)

            #expect(fixture.session.overlay == nil)
            #expect(fixture.presenter.shows.isEmpty)
            #expect(fixture.presenter.hideCount == 0)
        }

        @Test
        func `losing key status while shown closes the hints without clicking`() {
            let fixture = Fixture(targetCount: 3)
            fixture.session.trigger(.clickInWindow)

            fixture.presenter.dismiss()
            fixture.turns.runAll()

            #expect(fixture.session.overlay == nil)
            #expect(fixture.presenter.hideCount == 1)
            #expect(fixture.clicker.clicks.isEmpty)
        }

        @Test
        func `a dismissal after the hints are gone changes nothing`() {
            let fixture = Fixture(targetCount: 3)
            fixture.session.trigger(.clickInWindow)
            fixture.presenter.type(.escape)

            fixture.presenter.dismiss()

            #expect(fixture.session.overlay == nil)
            #expect(fixture.presenter.hideCount == 1)
        }

        @Test
        func `handlers from a replaced overlay are ignored`() throws {
            let fixture = Fixture(targetCount: 3)
            fixture.session.trigger(.clickInWindow)
            let stale = try #require(fixture.presenter.shows.first)
            fixture.session.trigger(.rightClickInWindow)
            let shown = fixture.session.overlay

            stale.onKey(.character("a"))
            stale.onDismiss()
            fixture.turns.runAll()

            #expect(fixture.session.overlay == shown)
            #expect(fixture.presenter.hideCount == 1)
            #expect(fixture.clicker.clicks.isEmpty)
        }

        @Test
        func `a disabled app frontmost reads nothing, for the moment before the switch lands`() {
            var config = HintjumpConfig.default
            config.disabledApps = ["com.apple.finder"]
            let frozen = config
            let collector = FakeHintTargetCollector(answering: HintSessionTests.targetSet(count: 3))
            let presenter = FakeHintOverlayPresenter(screen: HintSessionTests.screen)
            let session = HintSession(
                frontmostApp: FakeFrontmostAppProvider(answering: [HintSessionTests.app]),
                collectors: [.clickInWindow: collector],
                presenter: presenter,
                clicker: FakeClickPerformer(),
                configuration: { frozen },
                deferToNextTurn: { _ in
                    // Nothing is shown, so no click is ever deferred.
                },
            )

            session.trigger(.clickInWindow)

            #expect(session.overlay == nil)
            #expect(collector.collectedApps.isEmpty)
            #expect(presenter.shows.isEmpty)
        }
    }
}
