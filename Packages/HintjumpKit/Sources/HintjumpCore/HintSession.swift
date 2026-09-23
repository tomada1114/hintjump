import CoreGraphics
import Foundation
import Observation

/// One hint session, start to finish: trigger → read → rank → label → place → show →
/// match keys → hide → click.
///
/// That sequence is the product (`AGENTS.md` › Product › "The core interaction"), and
/// every step of it is a decision, so it lives here under the coverage floor with the
/// OS reached through ports: ``FrontmostAppProviding`` for who to read,
/// ``HintTargetCollecting`` for what to hint, ``HintOverlayPresenting`` for the overlay
/// and its keys, and ``ClickPerforming`` for the click. `@Observable` so the overlay view
/// renders ``overlay`` and nothing else.
///
/// Pressing the same trigger again closes the hints; a different trigger replaces them
/// (`docs/decisions.md` › "Pressing the same trigger again closes the hints; a different
/// trigger replaces them").
@MainActor
@Observable
public final class HintSession {
    /// Runs work on a later main-run-loop turn.
    public typealias DeferToNextTurn = @MainActor (@escaping @MainActor () -> Void) -> Void

    /// What the overlay shows, or `nil` while no hints are up.
    public private(set) var overlay: HintOverlayState?

    @ObservationIgnored private let frontmostApp: any FrontmostAppProviding
    @ObservationIgnored private let collectors: [EntryPoint: any HintTargetCollecting]
    @ObservationIgnored private let presenter: any HintOverlayPresenting
    @ObservationIgnored private let clicker: any ClickPerforming
    @ObservationIgnored private let configuration: @MainActor () -> HintjumpConfig
    @ObservationIgnored private let deferToNextTurn: DeferToNextTurn
    @ObservationIgnored private var active: ActiveHints?
    @ObservationIgnored private var generation = 0

    /// A session with nothing shown.
    ///
    /// - Parameters:
    ///   - collectors: One per entry point that can show hints; a trigger with none is
    ///     logged as not available yet.
    ///   - configuration: Read on every trigger, so a reloaded config's hint characters
    ///     apply to the next press.
    ///   - deferToNextTurn: How a click is put off until after the overlay is hidden, so
    ///     the window server has ordered the overlay out before the click lands. The
    ///     default hops through the main dispatch queue; a test passes one it controls.
    public init(
        frontmostApp: any FrontmostAppProviding,
        collectors: [EntryPoint: any HintTargetCollecting],
        presenter: any HintOverlayPresenting,
        clicker: any ClickPerforming,
        configuration: @escaping @MainActor () -> HintjumpConfig,
        deferToNextTurn: @escaping DeferToNextTurn = HintSession.onNextMainTurn,
    ) {
        self.frontmostApp = frontmostApp
        self.collectors = collectors
        self.presenter = presenter
        self.clicker = clicker
        self.configuration = configuration
        self.deferToNextTurn = deferToNextTurn
    }

    /// The default ``DeferToNextTurn``: `work` runs on the main queue's next turn.
    public static func onNextMainTurn(_ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async {
            work()
        }
    }

    /// `key` with a character lowercased; any other key, and a character whose lowercase
    /// form is not one character, unchanged.
    private static func lowercased(_ key: HintKey) -> HintKey {
        guard case let .character(character) = key else {
            return key
        }
        let lowered = character.lowercased()
        guard lowered.count == 1, let first = lowered.first else {
            return key
        }
        return .character(first)
    }

    /// What a read that ends in ``AccessibilityReadError/attributeUnsupported(_:)``
    /// was missing, for the `trigger ignored` log line: the attribute is the root of
    /// `entryPoint`'s read, so the window triggers lack a focused window and the menu-bar
    /// ones a menu bar. The status-items collector reads no attribute today; should it
    /// ever, the menu bar is where its items live.
    static func unsupportedAttributeReason(for entryPoint: EntryPoint) -> String {
        switch entryPoint {
        case .clickInWindow, .rightClickInWindow:
            "no focused window"

        case .appMenus, .statusIcons:
            "no menu bar"
        }
    }

    /// `duration` in whole milliseconds, for a log line.
    private static func milliseconds(_ duration: Duration) -> Int {
        Int((duration / .milliseconds(1)).rounded())
    }

    /// Handles a press of `entryPoint`'s shortcut.
    ///
    /// With hints up, the press closes them (reason `retrigger`); the same trigger stops
    /// there, a different one goes on to show its own. Nothing is shown — and why is
    /// logged — when the entry point has no collector, there is no frontmost app with a
    /// process identifier, the frontmost app is a disabled one or — for a collector that
    /// reads it (``HintTargetCollecting/readsFrontmostApp``) — this one, the read fails,
    /// or no target gets a label.
    public func trigger(_ entryPoint: EntryPoint) {
        let clock = ContinuousClock()
        let start = clock.now
        if let active {
            cancel(.retrigger)
            if active.entryPoint == entryPoint {
                return
            }
        }
        guard let collector = collector(for: entryPoint),
              let app = appToCollect(for: collector),
              let set = collect(with: collector, from: app, for: entryPoint),
              present(set, for: entryPoint)
        else {
            return
        }
        let total = start.duration(to: clock.now)
        let labeled = overlay?.hints.count ?? 0
        let targets = set.targets.count
        let container = set.container?.rawValue ?? "-"
        let scope = set.container?.scope.rawValue ?? "-"
        AppLog.hints.info(
            // swiftlint:disable:next line_length
            "shown entry=\(entryPoint.rawValue, privacy: .public) container=\(container, privacy: .public) scope=\(scope, privacy: .public) pid=\(set.pid, privacy: .public) targets=\(targets, privacy: .public) labeled=\(labeled, privacy: .public) unlabeled=\(targets - labeled, privacy: .public) read=\(Self.milliseconds(set.readDuration), privacy: .public)ms total=\(Self.milliseconds(total), privacy: .public)ms",
        )
    }

    /// Handles one key typed at the overlay.
    ///
    /// A character is lowercased first — the trigger's Shift may still be held — and
    /// then matched: a narrowing or a backspace updates ``overlay``, Esc closes the
    /// hints, a completed label clicks, and any other key is swallowed with nothing
    /// changed. With no hints up, every key is ignored.
    public func handle(_ key: HintKey) {
        guard var current = active else {
            return
        }
        let outcome = current.matcher.handle(Self.lowercased(key))
        active = current
        switch outcome {
        case .narrowed, .widened:
            overlay?.hints = current.visibleHints

        case .ignored:
            break

        case .cancelled:
            cancel(.escape)

        case let .selected(label):
            select(label, from: current)
        }
    }

    // MARK: - Trigger steps

    private func collector(for entryPoint: EntryPoint) -> (any HintTargetCollecting)? {
        guard let collector = collectors[entryPoint] else {
            AppLog.hints.info(
                "trigger ignored: entry point not available yet entry=\(entryPoint.rawValue, privacy: .public)",
            )
            return nil
        }
        return collector
    }

    /// The frontmost app to hand `collector`: one with a process identifier that is not
    /// disabled, and — when `collector` reads it — another process than this one.
    private func appToCollect(for collector: any HintTargetCollecting) -> FrontmostApp? {
        guard let app = frontmostApp.currentFrontmostApp() else {
            AppLog.hints.info("trigger ignored: no frontmost app")
            return nil
        }
        guard let pid = app.processIdentifier else {
            AppLog.hints.info("trigger ignored: frontmost app has no process identifier")
            return nil
        }
        guard pid != ProcessInfo.processInfo.processIdentifier || !collector.readsFrontmostApp
        else {
            AppLog.hints.info("trigger ignored: Hintjump itself is frontmost")
            return nil
        }
        // The triggers are unregistered while a disabled app is frontmost
        // (`DisabledAppsPolicy`), but a press can land between an app switch and its
        // notification.
        if let bundleID = app.bundleIdentifier, configuration().disabledApps.contains(bundleID) {
            AppLog.hints.info("trigger ignored: disabled app")
            return nil
        }
        return app
    }

    private func collect(
        with collector: any HintTargetCollecting,
        from app: FrontmostApp,
        for entryPoint: EntryPoint,
    ) -> TargetSet? {
        do {
            return try collector.collect(from: app)
        } catch AccessibilityReadError.notTrusted {
            AppLog.hints.info("trigger ignored: accessibility not granted")
        } catch AccessibilityReadError.attributeUnsupported {
            AppLog.hints.info(
                // swiftlint:disable:next line_length
                "trigger ignored: \(Self.unsupportedAttributeReason(for: entryPoint), privacy: .public) entry=\(entryPoint.rawValue, privacy: .public)",
            )
        } catch {
            AppLog.hints.error("trigger failed: \(String(describing: error), privacy: .public)")
        }
        return nil
    }

    /// Labels, places, and shows `set`, and says whether it did: when no target gets a
    /// label, it logs that and shows nothing.
    private func present(_ set: TargetSet, for entryPoint: EntryPoint) -> Bool {
        let assignment = LabelAssigner().assign(
            set.targets,
            characters: configuration().hintCharacters,
        )
        guard !assignment.labeled.isEmpty else {
            AppLog.hints.info("no targets entry=\(entryPoint.rawValue, privacy: .public)")
            return false
        }
        let rootCenter = CGPoint(x: set.rootFrame.midX, y: set.rootFrame.midY)
        let canvas = presenter.screenFrame(containing: rootCenter) ?? set.rootFrame
        let placed = assignment.labeled.map { labeled in
            HintLayout.placedHint(
                label: labeled.label,
                targetFrame: labeled.target.frame,
                in: canvas,
            )
        }
        let rightClick = entryPoint == .rightClickInWindow
        generation += 1
        active = ActiveHints(
            entryPoint: entryPoint,
            generation: generation,
            assignment: assignment,
            placed: placed,
            matcher: HintMatcher(labels: assignment.labels),
        )
        overlay = HintOverlayState(
            entryPoint: entryPoint,
            style: rightClick ? .outlined : .filled,
            canvas: canvas,
            hints: placed,
            chip: rightClick ? HintLayout.chip(for: set.rootFrame, in: canvas) : nil,
        )
        showOverlay(on: canvas, generation: generation)
        return true
    }

    /// Asks the presenter to show the overlay, with handlers that answer only while
    /// `generation`'s hints are the ones up.
    private func showOverlay(on canvas: CGRect, generation: Int) {
        presenter.show(
            canvas: canvas,
            onKey: { [weak self] key in
                self?.receive(key, forGeneration: generation)
            },
            onDismiss: { [weak self] in
                self?.dismissed(generation: generation)
            },
        )
    }

    // MARK: - Ending the hints

    /// A key from the overlay `generation` showed; one from a replaced overlay is stale.
    private func receive(_ key: HintKey, forGeneration generation: Int) {
        guard active?.generation == generation else {
            return
        }
        handle(key)
    }

    /// The overlay `generation` showed went away on its own. Because the session clears
    /// its state before it hides, a dismissal the hide itself causes finds nothing active.
    private func dismissed(generation: Int) {
        guard active?.generation == generation else {
            return
        }
        cancel(.resigned)
    }

    private func cancel(_ reason: HintCancelReason) {
        guard let current = active else {
            return
        }
        active = nil
        overlay = nil
        presenter.hide()
        AppLog.hints.info(
            "cancel reason=\(reason.rawValue, privacy: .public) entry=\(current.entryPoint.rawValue, privacy: .public)",
        )
    }

    /// Hides the hints, then clicks `label`'s target on the next turn.
    private func select(_ label: String, from hints: ActiveHints) {
        active = nil
        overlay = nil
        presenter.hide()
        guard let target = hints.assignment.target(labeled: label) else {
            return
        }
        let button: MouseButton = hints.entryPoint == .rightClickInWindow ? .right : .left
        AppLog.hints.info(
            // swiftlint:disable:next line_length
            "click entry=\(hints.entryPoint.rawValue, privacy: .public) button=\(button.rawValue, privacy: .public) label=\(label, privacy: .public)",
        )
        let performer = clicker
        deferToNextTurn {
            do {
                try performer.click(at: target.clickPoint, button: button)
            } catch {
                AppLog.hints.error("click failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
