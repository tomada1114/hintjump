/// A port: hand the configuration file to the user's editor, or to Finder.
///
/// Which editor, and what to do when there is none, is `NSWorkspace`'s answer, and
/// `AppKit` is one of the frameworks Core may not import (`docs/architecture.md` ›
/// Layers). The status menu's "Open Config File" and the Settings window's Config File
/// pane ("Open", "Reveal in Finder") are the callers; both methods are the same
/// capability — giving the file to another app — so they share one port.
@MainActor
public protocol ConfigFileOpening: Sendable {
    /// Opens the file at `path` in the user's editor. Nothing is reported back: a user
    /// who sees no editor appear knows as much as the app would.
    func open(path: String)

    /// Shows the file at `path` selected in a Finder window. Nothing is reported back,
    /// for the same reason as ``open(path:)``.
    func reveal(path: String)
}
