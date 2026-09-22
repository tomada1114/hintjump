import CoreGraphics

/// The frontmost-window entry points' collector: reads the frontmost application's
/// focused window, ranks what can be clicked in it, and fixes where each is clicked.
///
/// It reads with ``ReadStrategy/batchedPruned`` (`docs/decisions.md` › "The reader's
/// strategy is batchedPruned; the read alone gets 200 ms") through one
/// ``ManualAccessibilityWaker``, so a Chromium or Electron window whose tree comes back
/// empty is woken at most once per process for the collector's lifetime. One instance
/// serves both window entry points, so they share that memory.
///
/// Only the focused window is read. Targeting an open menu, popover, or another
/// process's panel first is a later collector's job, plugged in through
/// ``HintTargetCollecting``.
@MainActor
public final class WindowTargetCollector: HintTargetCollecting {
    private let waker: ManualAccessibilityWaker
    private let ranker: TargetRanker

    /// Reads through `reader`, woken as needed, and orders targets with `ranker`.
    public init(reader: any AccessibilityTreeReading, ranker: TargetRanker = TargetRanker()) {
        waker = ManualAccessibilityWaker(reader: reader)
        self.ranker = ranker
    }

    /// The focused window's targets, likeliest first.
    ///
    /// A window that reports no frame yields an empty set with a zero ``TargetSet/rootFrame``:
    /// there is nothing to clip a click point to, and the session shows nothing for an
    /// empty set anyway. An `app` with no process identifier names no process, so it
    /// throws ``AccessibilityReadError/noSuchProcess(_:)`` with pid 0 without reading;
    /// the session never passes one.
    public func collect(from app: FrontmostApp) throws -> TargetSet {
        guard let pid = app.processIdentifier else {
            throw AccessibilityReadError.noSuchProcess(0)
        }
        let snapshot = try waker.readTree(pid: pid, scope: .focusedWindow, strategy: .batchedPruned)
        let rootFrame = snapshot.elements.first?.frame ?? .zero
        let targets = ranker.rank(snapshot.elements).compactMap { ranked -> HintTarget? in
            guard let frame = ranked.element.frame,
                  let clickPoint = ClickPointRule.point(for: frame, within: rootFrame)
            else {
                return nil
            }
            return HintTarget(frame: frame, clickPoint: clickPoint, role: ranked.element.role)
        }
        return TargetSet(
            pid: pid,
            bundleIdentifier: snapshot.bundleIdentifier,
            rootFrame: rootFrame,
            targets: targets,
            readDuration: snapshot.readDuration,
        )
    }
}
