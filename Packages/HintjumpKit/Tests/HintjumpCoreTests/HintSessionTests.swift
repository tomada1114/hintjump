import CoreGraphics
import Foundation
import HintjumpCore
import Testing

/// The hint session's suites share one fixture, declared here; the suites themselves
/// are nested, one per concern, in its `+Trigger` and `+Keys` extensions.
@Suite("HintSession")
enum HintSessionTests {
    /// One hint session wired to a fake of every port, as `App/` will wire the real ones.
    @MainActor
    struct Fixture {
        let provider: FakeFrontmostAppProvider
        let collector: FakeHintTargetCollector
        let presenter: FakeHintOverlayPresenter
        let clicker = FakeClickPerformer()
        let turns = DeferredTurns()
        let session: HintSession

        /// Finder frontmost, its window offering `targetCount` targets, on
        /// ``HintSessionTests/screen``.
        init(targetCount: Int) {
            self.init(
                app: HintSessionTests.app,
                collector: FakeHintTargetCollector(answering: HintSessionTests
                    .targetSet(count: targetCount)),
                screen: HintSessionTests.screen,
            )
        }

        /// `app` frontmost, `collector` behind both window entry points and none behind
        /// the menu-bar ones, and a presenter whose every point is on `screen`.
        init(app: FrontmostApp?, collector: FakeHintTargetCollector, screen: CGRect?) {
            self.init(
                app: app,
                collector: collector,
                screen: screen,
                entryPoints: [.clickInWindow, .rightClickInWindow],
            )
        }

        /// `app` frontmost, `collector` behind `entryPoints` and no collector behind any
        /// other, and a presenter whose every point is on `screen`.
        init(
            app: FrontmostApp?,
            collector: FakeHintTargetCollector,
            screen: CGRect?,
            entryPoints: [EntryPoint],
        ) {
            provider = FakeFrontmostAppProvider(answering: [app])
            self.collector = collector
            presenter = FakeHintOverlayPresenter(screen: screen)
            let deferred = turns
            session = HintSession(
                frontmostApp: provider,
                collectors: Dictionary(uniqueKeysWithValues: entryPoints.map { ($0, collector) }),
                presenter: presenter,
                clicker: clicker,
                configuration: { .default },
                deferToNextTurn: { deferred.schedule($0) },
            )
        }
    }

    static let pid: pid_t = 777
    static let app = FrontmostApp(
        name: "Finder",
        bundleIdentifier: "com.apple.finder",
        processIdentifier: pid,
    )
    static let rootFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
    static let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
    /// The first target's frame; each later one is offset 1 pt right and down from the
    /// one before, so every target and click point is distinct.
    static let firstTargetFrame = CGRect(x: 200, y: 150, width: 40, height: 20)
    static let readDuration: Duration = .milliseconds(40)

    /// `count` distinct targets inside ``rootFrame``, each clicked at its own point.
    static func targets(count: Int) -> [HintTarget] {
        (0 ..< count).map { index in
            let frame = firstTargetFrame.offsetBy(dx: CGFloat(index), dy: CGFloat(index))
            return HintTarget(
                frame: frame,
                clickPoint: CGPoint(x: frame.midX, y: frame.midY),
                role: "AXButton",
            )
        }
    }

    static func targetSet(count: Int) -> TargetSet {
        TargetSet(
            pid: pid,
            bundleIdentifier: "com.apple.finder",
            rootFrame: rootFrame,
            targets: targets(count: count),
            readDuration: readDuration,
        )
    }

    /// The tags the default configuration puts on the first `count` targets, on ``screen``.
    static func hints(count: Int) -> [PlacedHint] {
        let labels = LabelAssigner().labels(
            count: count,
            characters: HintjumpConfig.default.hintCharacters,
        )
        let tags = zip(labels, targets(count: count)).map { label, target in
            LabeledFrame(label: label, frame: target.frame)
        }
        return HintLayout.placedHints(tags, within: rootFrame, in: screen)
    }
}
