/// "What can be hinted for this entry point right now?" — one implementation per entry
/// point, so the hint session runs every entry point the same way.
///
/// The frontmost-window entry points share ``WindowTargetCollector``; the menu-bar entry
/// points add their own collectors without touching ``HintSession``. `@MainActor`
/// because a collector reads through ``AccessibilityTreeReading``, which is.
@MainActor
public protocol HintTargetCollecting: Sendable {
    /// Whether ``collect(from:)`` reads the app it is handed.
    ///
    /// The session never hands Hintjump itself to a collector that reads it: its own
    /// windows are not what a trigger is for. A collector whose targets come from
    /// elsewhere, such as
    /// ``StatusItemTargetCollector``, says `false` and gets the press anyway. `true`
    /// unless a collector says otherwise.
    var readsFrontmostApp: Bool { get }

    /// The targets `app` offers this entry point, in rank order.
    ///
    /// Throws what the read threw — ``AccessibilityReadError`` from a reader — so the
    /// session can tell a missing grant from a missing window.
    func collect(from app: FrontmostApp) throws -> TargetSet
}

// SwiftFormat's `--extensionacl on-declarations` puts `public` on the member and this
// rule wants it on the extension; the two agree only on mixed access, which one member
// cannot have.
// swiftlint:disable:next extension_access_modifier
extension HintTargetCollecting {
    /// A collector reads the frontmost app unless it says otherwise.
    public var readsFrontmostApp: Bool {
        true
    }
}
