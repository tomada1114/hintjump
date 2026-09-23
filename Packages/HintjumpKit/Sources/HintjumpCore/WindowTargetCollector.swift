import CoreGraphics
import Foundation

/// The frontmost-window entry points' collector: reads whatever is on top of the
/// frontmost application — another process's panel, a context menu, a sheet, a popover,
/// or the focused window — ranks what can be clicked in it, and fixes where each is
/// clicked.
///
/// What is on top is ``TopmostContainerRule``'s decision, made on every press from the
/// signals ``TopmostContainerProbing`` reads before any tree is walked. A resolved panel
/// or menu that cannot be read after all — a menu fading out, a panel that closed in
/// between — falls back to the frontmost application's focused window, today's target,
/// so a press never shows less than it did before the rule.
///
/// It reads with ``ReadStrategy/batchedPruned`` (`docs/decisions.md` › "The reader's
/// strategy is batchedPruned; the read alone gets 200 ms") through one
/// ``ManualAccessibilityWaker``, so a Chromium or Electron window whose tree comes back
/// empty is woken at most once per process for the collector's lifetime. One instance
/// serves both window entry points, so they share that memory.
@MainActor
public final class WindowTargetCollector: HintTargetCollecting {
    private let waker: ManualAccessibilityWaker
    private let probe: any TopmostContainerProbing
    private let ranker: TargetRanker
    private let ownPID: pid_t

    /// Reads through `reader`, woken as needed, after asking `probe` what is on top, and
    /// orders targets with `ranker`.
    ///
    /// `ownPID` is the process whose focus never counts as another process's panel —
    /// Hintjump's own, whose overlay takes system focus while it is shown.
    public init(
        reader: any AccessibilityTreeReading,
        probe: any TopmostContainerProbing,
        ranker: TargetRanker = TargetRanker(),
        ownPID: pid_t = ProcessInfo.processInfo.processIdentifier,
    ) {
        waker = ManualAccessibilityWaker(reader: reader)
        self.probe = probe
        self.ranker = ranker
        self.ownPID = ownPID
    }

    /// The topmost container's targets, likeliest first.
    ///
    /// The set's ``TargetSet/pid`` is the process that was read — another one's for a
    /// panel it drew — and its ``TargetSet/container`` names what was labeled. A container
    /// that reports no frame yields an empty set with a zero ``TargetSet/rootFrame``:
    /// there is nothing to clip a click point to, and the session shows nothing for an
    /// empty set anyway. An `app` with no process identifier names no process, so it
    /// throws ``AccessibilityReadError/noSuchProcess(_:)`` with pid 0 without reading;
    /// the session never passes one. A missing grant is thrown at once; any other failure
    /// of the focused-window read is thrown as it was.
    public func collect(from app: FrontmostApp) throws -> TargetSet {
        guard let pid = app.processIdentifier else {
            throw AccessibilityReadError.noSuchProcess(0)
        }
        let (read, snapshot) = try readTopmost(frontmostPID: pid)
        let (container, elements) = read.container == .focusedWindow
            ? TopmostContainerRule.container(in: snapshot.elements)
            : (read.container, snapshot.elements)
        let rootFrame = elements.first?.frame ?? .zero
        let targets = ranker.rank(elements).compactMap { ranked -> HintTarget? in
            guard let frame = ranked.element.frame,
                  let clickPoint = ClickPointRule.point(for: frame, within: rootFrame)
            else {
                return nil
            }
            return HintTarget(frame: frame, clickPoint: clickPoint, role: ranked.element.role)
        }
        return TargetSet(
            pid: read.pid,
            bundleIdentifier: snapshot.bundleIdentifier,
            rootFrame: rootFrame,
            targets: targets,
            readDuration: snapshot.readDuration,
            container: container,
        )
    }

    /// Asks the probe, resolves, and reads — falling back to the frontmost application's
    /// focused window when the resolved panel or menu cannot be read.
    private func readTopmost(frontmostPID: pid_t) throws -> (TopmostRead, TreeSnapshot) {
        let clock = ContinuousClock()
        let start = clock.now
        let signals = probe.signals()
        let probeDuration = start.duration(to: clock.now)
        let resolved = TopmostContainerRule.resolve(
            signals,
            frontmostPID: frontmostPID,
            ownPID: ownPID,
        )
        AppLog.accessibility.debug(
            // swiftlint:disable:next line_length
            "topmost resolved container=\(resolved.container.rawValue, privacy: .public) scope=\(resolved.scope.rawValue, privacy: .public) pid=\(resolved.pid, privacy: .public) focusedApp=\(signals.focusedApplicationPID.map(String.init) ?? "-", privacy: .public) raised=\(signals.raisedWindows.count, privacy: .public) probe=\(probeDuration / .milliseconds(1), privacy: .public)ms",
        )
        let fallback = TopmostRead(
            pid: frontmostPID,
            scope: .focusedWindow,
            container: .focusedWindow,
        )
        if resolved != fallback {
            do {
                return try (resolved, read(resolved))
            } catch AccessibilityReadError.notTrusted {
                throw AccessibilityReadError.notTrusted
            } catch {
                AppLog.accessibility.debug(
                    // swiftlint:disable:next line_length
                    "topmost fallback from=\(resolved.container.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)",
                )
            }
        }
        return try (fallback, read(fallback))
    }

    private func read(_ target: TopmostRead) throws -> TreeSnapshot {
        try waker.readTree(pid: target.pid, scope: target.scope, strategy: .batchedPruned)
    }
}
