/// "What can be hinted for this entry point right now?" — one implementation per entry
/// point, so the hint session runs every entry point the same way.
///
/// The frontmost-window entry points share ``WindowTargetCollector``; the menu-bar entry
/// points add their own collectors without touching ``HintSession``. `@MainActor`
/// because a collector reads through ``AccessibilityTreeReading``, which is.
@MainActor
public protocol HintTargetCollecting: Sendable {
    /// The targets `app` offers this entry point, in rank order.
    ///
    /// Throws what the read threw — ``AccessibilityReadError`` from a reader — so the
    /// session can tell a missing grant from a missing window.
    func collect(from app: FrontmostApp) throws -> TargetSet
}
