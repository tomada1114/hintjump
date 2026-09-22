import AppKit
import HintjumpCore

/// The `NSWorkspace`-backed adapter for ``HintjumpCore/SystemSettingsOpening``.
///
/// Opens the same pane URL System Settings itself links to from a permission alert;
/// translation only, no branching logic — the decision of *when* to call this lives in
/// the Status window's view, not here.
public struct WorkspaceSystemSettingsOpener: SystemSettingsOpening {
    /// The deep link to Privacy & Security › Accessibility.
    private static let accessibilityPaneURLString =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    public init() {
        // Stateless: NSWorkspace.shared is the whole dependency.
    }

    /// Opens the Privacy & Security › Accessibility pane.
    ///
    /// The return value of `NSWorkspace.open` is dropped: there is nothing meaningful
    /// this adapter can do with "System Settings failed to open" beyond what the user
    /// already sees (nothing happened), and Core has no state that failure would change.
    /// `URL(string:)` failing is likewise not something to force-unwrap over: the literal
    /// is fixed, so a failure here could only mean the literal itself broke, in which
    /// case declining silently is no worse than crashing the app over it.
    public func openAccessibilitySettings() {
        guard let url = URL(string: Self.accessibilityPaneURLString) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
