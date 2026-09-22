/// A port: open the configuration file for the user to edit.
///
/// Which editor, and what to do when there is none, is `NSWorkspace`'s answer, and
/// `AppKit` is one of the frameworks Core may not import (`docs/architecture.md` ›
/// Layers). The status menu's "Open Config File" is the only caller, so the port is one
/// method deep, like ``SystemSettingsOpening``.
@MainActor
public protocol ConfigFileOpening: Sendable {
    /// Opens the file at `path` in the user's editor. Nothing is reported back: a user
    /// who sees no editor appear knows as much as the app would.
    func open(path: String)
}
