/// A port: open a specific pane of System Settings.
///
/// A separate, tiny port from ``AccessibilityTrustChecking`` because it is a different
/// capability — no TCC check, just handing the OS a URL — and because the Status window's
/// "Open System Settings…" button is the only caller: keeping it apart from the trust
/// check lets each port stay one method deep.
@MainActor
public protocol SystemSettingsOpening: Sendable {
    /// Opens the Privacy & Security › Accessibility pane.
    func openAccessibilitySettings()
}
