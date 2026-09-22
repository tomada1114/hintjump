import Foundation

/// Applies ``EmptyWebAreaRule`` against ``AccessibilityTreeReading``: wakes a Chromium
/// or Electron process's tree at most once per process, only after a read reveals it
/// needs waking.
///
/// `docs/decisions.md` › "Chromium-based apps are in the first release's scope; no wake
/// by default" is explicit that `AXManualAccessibility` is never set up front — only
/// after a read comes back with an empty `AXWebArea`, and never twice for the same
/// process. This type is the one place that sequence lives; ``WindowTargetCollector``,
/// behind the frontmost-window entry points, is its product caller.
@MainActor
public final class ManualAccessibilityWaker {
    private let reader: AccessibilityTreeReading
    private var wokenPIDs: Set<pid_t> = []

    /// Wraps `reader`; no pid is considered woken until a read of it matches
    /// ``EmptyWebAreaRule``.
    public init(reader: AccessibilityTreeReading) {
        self.reader = reader
    }

    /// Reads `pid`'s tree under `scope` with `strategy`. If the read matches
    /// ``EmptyWebAreaRule`` and this pid has not been woken yet, sets
    /// `AXManualAccessibility` once, remembers the pid so it is never set again for this
    /// process, and reads again.
    ///
    /// When ``AccessibilityTreeReading/enableManualAccessibility(pid:)`` answers
    /// ``AccessibilityReadError/attributeUnsupported(_:)``, this process needs no
    /// waking (the attribute has no meaning for it) — the pid is still remembered so no
    /// retry is attempted, and the first snapshot is returned since a second read has
    /// nothing new to find.
    public func readTree(
        pid: pid_t,
        scope: ReadScope,
        strategy: ReadStrategy,
    ) throws -> TreeSnapshot {
        let snapshot = try reader.readTree(pid: pid, scope: scope, strategy: strategy)
        guard EmptyWebAreaRule.matches(snapshot), !wokenPIDs.contains(pid) else {
            return snapshot
        }
        wokenPIDs.insert(pid)
        do {
            try reader.enableManualAccessibility(pid: pid)
        } catch AccessibilityReadError.attributeUnsupported {
            return snapshot
        }
        return try reader.readTree(pid: pid, scope: scope, strategy: strategy)
    }
}
